package main

import (
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	handlers "todo-api/handlers"
	models "todo-api/models"
	utils "todo-api/utils"

	"github.com/gorilla/mux"
	log "github.com/sirupsen/logrus"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rs/cors"
	"gorm.io/driver/sqlite"
	"gorm.io/driver/sqlserver"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"gorm.io/plugin/opentelemetry/logging/logrus"
	gprom "gorm.io/plugin/prometheus"
)

var (
	dsn               = utils.GetEnvAsString("DB_CXN", "")
	listenAddr        = utils.GetEnvAsString("LISTEN_ADDR", "8080")
	metricsListenAddr = utils.GetEnvAsString("METRICS_LISTEN_ADDR", "8081")
	maxIdleDbCxns     = utils.GetEnvAsInt("MAX_IDLE_DB_CXNS", 5)
	maxOpenDbCxns     = utils.GetEnvAsInt("MAX_OPEN_DB_CXNS", 10)
	wg                sync.WaitGroup
)

func initDb(dsn string, logger logger.Interface, maxIdleDbCxns int, maxOpenDbCxns int) (env *handlers.Env) {
	if strings.TrimSpace(dsn) == "" {
		log.Info("using local in memory SQLite database")
		db, err := gorm.Open(sqlite.Open("file:memdb1?mode=memory&cache=shared"), &gorm.Config{Logger: logger})
		if err != nil {
			log.Errorf("Failed to open local db with error: %v", err)
		}

		env = &handlers.Env{Db: db}
	} else {
		log.Info("using Azure SQL database")
		db, err := gorm.Open(sqlserver.Open(dsn), &gorm.Config{Logger: logger})
		if err != nil {
			log.Errorf("Failed to open remote db with error: '%v'", err)
		}

		sqlDB, err := db.DB()
		if err != nil {
			log.Errorf("Failed to get sqlDB to configure Connection pool options with error: '%v'", err)
		}

		sqlDB.SetMaxIdleConns(maxIdleDbCxns)
		sqlDB.SetMaxOpenConns(maxOpenDbCxns)
		sqlDB.SetConnMaxLifetime(time.Hour)

		env = &handlers.Env{Db: db}
	}
	return env
}

func main() {
	defer wg.Done()

	logger := logger.New(
		logrus.NewWriter(),
		logger.Config{
			SlowThreshold: time.Millisecond,
			LogLevel:      logger.Info,
			Colorful:      false,
		},
	)

	env := initDb(dsn, logger, maxIdleDbCxns, maxOpenDbCxns)

	// add GORM OpenTelemetry tracing plugin
	env.Db.Use(gprom.New(gprom.Config{
		DBName:          env.Db.Name(), // use `DBName` as metrics label
		RefreshInterval: 15,            // Refresh metrics interval (default 15 seconds)
		PushAddr:        "",            // push metrics if `PushAddr` configured
		StartServer:     false,         // start http server to expose metrics
		HTTPServerPort:  8081,          // configure http server port, default port 8080 (if you have configured multiple instances, only the first `HTTPServerPort` will be used to start server)
		MetricsCollector: []gprom.MetricsCollector{
			&gprom.MySQL{
				VariableNames: []string{"Threads_running"},
			},
		}, // user defined metrics
	}))

	env.Db.Migrator().AutoMigrate(&models.TodoItemEntity{})

	metricsRouter := mux.NewRouter()
	metricsRouter.Use(handlers.PrometheusMiddleware)
	metricsRouter.HandleFunc("/metrics", promhttp.Handler().ServeHTTP).Methods("GET")

	metricsHandler := cors.New(cors.Options{
		AllowedMethods: []string{"GET", "POST", "DELETE", "PATCH", "OPTIONS"},
	}).Handler(metricsRouter)

	// create router & define routes
	router := mux.NewRouter()
	router.HandleFunc("/healthz/readiness", env.Readiness).Methods("GET")
	router.HandleFunc("/healthz/liveness", env.Liveness).Methods("GET")
	router.HandleFunc("/api/todos", env.GetAll).Methods("GET")
	router.HandleFunc("/api/todos/completed", env.GetCompleted).Methods("GET")
	router.HandleFunc("/api/todos/incomplete", env.GetIncomplete).Methods("GET")
	router.HandleFunc("/api/todos/{id}", env.GetById).Methods("GET")
	router.HandleFunc("/api/todos", env.Create).Methods("POST")
	router.HandleFunc("/api/todos/{id}", env.Update).Methods("PATCH")
	router.HandleFunc("/api/todos/complete/{id}", env.Complete).Methods("PATCH")
	router.HandleFunc("/api/todos/{id}", env.Delete).Methods("DELETE")

	handler := cors.New(cors.Options{
		AllowedMethods: []string{"GET", "POST", "DELETE", "PATCH", "OPTIONS"},
	}).Handler(router)

	// increment waitgroup
	wg.Add(2)

	// start api endpoint
	log.Info("Starting metrics API Server")
	go func() { http.ListenAndServe(fmt.Sprintf(":%s", metricsListenAddr), metricsHandler) }()

	// start metrics endpoint
	log.Info("Starting TodoList API Server")
	go func() { http.ListenAndServe(fmt.Sprintf(":%s", listenAddr), handler) }()
	wg.Wait()
}
