package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/mux"
	log "github.com/sirupsen/logrus"

	models "todo-api/models"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
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
	dsn               = os.Getenv("DSN")
	funcPrefix        = "/api"
	listenAddr        = ":8080"
	metricsListenAddr = ":8081"
	maxIdleDbCxns     = 5
	maxOpenDbCxns     = 10

	wg sync.WaitGroup

	getOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_get_total",
		Help: "The total number of 'get' events",
	})

	createOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_created_total",
		Help: "The total number of 'created' events",
	})

	updateOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_updated_total",
		Help: "The total number of 'updated' events",
	})

	completeOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_completed_total",
		Help: "The total number of 'completed' events",
	})

	deleteOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_deleted_total",
		Help: "The total number of 'deleted' events",
	})

	httpDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name: "todoapi_http_duration_seconds",
		Help: "Duration of HTTP requests.",
	}, []string{"path"})
)

type Env struct {
	db *gorm.DB
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
	env := &Env{db: nil}

	if strings.TrimSpace(dsn) == "" {
		log.Info("using local in memory SQLite database")
		db, err := gorm.Open(sqlite.Open("file:memdb1?mode=memory&cache=shared"), &gorm.Config{Logger: logger})
		if err != nil {
			log.Errorf("Failed to open local db with error: %v", err)
		}

		env = &Env{db: db}
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

		env = &Env{db: db}
	}

	// add GORM otel tracing plugin
	env.db.Use(gprom.New(gprom.Config{
		DBName:          env.db.Name(), // use `DBName` as metrics label
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

	env.db.Migrator().AutoMigrate(&models.TodoItemEntity{})

	log.Info("Starting ToDoList API Server")

	metricsRouter := mux.NewRouter()
	metricsRouter.Use(prometheusMiddleware)
	metricsRouter.HandleFunc("/metrics", promhttp.Handler().ServeHTTP).Methods("GET")

	metricsHandler := cors.New(cors.Options{
		AllowedMethods: []string{"GET", "POST", "DELETE", "PATCH", "OPTIONS"},
	}).Handler(metricsRouter)

	wg.Add(2)
	go func() { http.ListenAndServe(metricsListenAddr, metricsHandler) }()

	router := mux.NewRouter()
	router.HandleFunc("/healthz/readiness", readiness).Methods("GET")
	router.HandleFunc("/healthz/liveness", liveness).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos", funcPrefix), env.getAll).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos/completed", funcPrefix), env.getCompleted).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos/incomplete", funcPrefix), env.getIncomplete).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos/{id}", funcPrefix), env.getById).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos", funcPrefix), env.create).Methods("POST")
	router.HandleFunc(fmt.Sprintf("%s/todos/{id}", funcPrefix), env.update).Methods("PATCH")
	router.HandleFunc(fmt.Sprintf("%s/todos/complete/{id}", funcPrefix), env.complete).Methods("PATCH")
	router.HandleFunc(fmt.Sprintf("%s/todos/{id}", funcPrefix), env.delete).Methods("DELETE")

	handler := cors.New(cors.Options{
		AllowedMethods: []string{"GET", "POST", "DELETE", "PATCH", "OPTIONS"},
	}).Handler(router)

	go func() { http.ListenAndServe(listenAddr, handler) }()
	wg.Wait()
}

func readiness(w http.ResponseWriter, r *http.Request) {
	// test SQL connection only if "DSN" env var is supplied
	if strings.TrimSpace(dsn) != "" {
		_, err := gorm.Open(sqlserver.Open(dsn), &gorm.Config{})
		if err != nil {
			log.Fatalf("Failed to open db with error: %v", err)
			log.Info("API dependencies are degraded")
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			io.WriteString(w, fmt.Sprintf(`{"alive": false, "error": %s}`, err))
			return
		}
	}

	log.Info("API dependencies are OK")
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	io.WriteString(w, `{"alive": true}`)
}

func liveness(w http.ResponseWriter, r *http.Request) {
	log.Info("API Health is OK")
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	io.WriteString(w, `{"alive": true}`)
}

func init() {
	log.SetFormatter(&log.TextFormatter{})
	log.SetReportCaller(true)
}

func (env *Env) getAll(w http.ResponseWriter, r *http.Request) {
	env.db.DB()
	allTodoItems, err := models.GetAll(env.db)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
	}
	log.Info(fmt.Printf("TodoItem count: %d\n", len(allTodoItems)))
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(allTodoItems)

	// increment getOperations Prometheus counter
	getOperationsProcessed.Inc()
}

func (env *Env) getById(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	todoItem, err := models.GetById(env.db, id)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
		return
	}
	log.Info("TodoItem: %s", todoItem)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(todoItem)

	// increment getOperations Prometheus counter
	getOperationsProcessed.Inc()
}

func (env *Env) getCompleted(w http.ResponseWriter, r *http.Request) {
	log.Info("Get completed TodoItems")
	completedTodoItems, err := models.GetByCompletionStatus(env.db, true)
	fmt.Print(completedTodoItems)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(completedTodoItems)

	// increment getOperations Prometheus counter
	getOperationsProcessed.Inc()
}

func (env *Env) getIncomplete(w http.ResponseWriter, r *http.Request) {
	log.Info("Get Incomplete TodoItems")
	incompleteTodoItems, err := models.GetByCompletionStatus(env.db, false)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(incompleteTodoItems)

	// increment getOperations Prometheus counter
	getOperationsProcessed.Inc()
}

func (env *Env) create(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	t := models.CreateOrUpdateTodoItem{}

	err := json.NewDecoder(r.Body).Decode(&t)
	if err != nil {
		errMsg := fmt.Sprintf("{\"created: false, \"error\": \"%s\"}", err)
		io.WriteString(w, errMsg)
	}
	defer r.Body.Close()

	if t.Description == "" {
		errMsg := "{\"created: false, \"error\": \"Description must not be empty\"}"
		io.WriteString(w, errMsg)
		return
	}

	log.WithFields(log.Fields{"description": t.Description}).Info("Add new TodoItem. Saving to database...")
	todo := &models.TodoItemEntity{Description: t.Description, Completed: false}
	env.db.Create(&todo)
	result := env.db.Last(&todo)
	json.NewEncoder(w).Encode(result.RowsAffected)

	// increment createdOperations Prometheus counter
	createOperationsProcessed.Inc()
}

func (env *Env) update(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	var t models.CreateOrUpdateTodoItem

	decoder := json.NewDecoder(r.Body)
	if err := decoder.Decode(&t); err != nil {
		io.WriteString(w, `{"created: false, "error": "error marshalling JSON to todo item"}`)
	}
	defer r.Body.Close()

	if todoItem, err := models.GetById(env.db, id); err != nil {
		io.WriteString(w, `{"updated": "false", "error": "Record Not Found"}`)
	} else {
		log.WithFields(log.Fields{"Id": id}).Info("Updating TodoItem")
		todoItem.Description = t.Description
		env.db.Save(&todoItem)
		io.WriteString(w, `{"updated": true}`)

		// increment updateOperations Prometheus counter
		updateOperationsProcessed.Inc()
	}
}

func (env *Env) complete(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	if todoItem, err := models.GetById(env.db, id); err != nil {
		io.WriteString(w, `{"deleted": false, "error": "Record Not Found"}`)
	} else {
		if todoItem.Completed {
			todoItem.Completed = false
		} else {
			todoItem.Completed = true
		}
		env.db.Save(&todoItem)
		io.WriteString(w, `{"updated": true}`)

		// increment completeOperations Prometheus counter
		completeOperationsProcessed.Inc()
	}
}

func (env *Env) delete(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	if todoItem, err := models.GetById(env.db, id); err != nil {
		io.WriteString(w, `{"deleted": "false", "error": "Record Not Found"}`)
	} else {
		log.WithFields(log.Fields{"Id": id}).Info("Delete TodoItem")
		env.db.Delete(&todoItem)
		io.WriteString(w, `{"deleted": true}`)

		// increment completeOperations Prometheus counter
		deleteOperationsProcessed.Inc()
	}
}

// prometheusMiddleware implements mux.MiddlewareFunc
func prometheusMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		route := mux.CurrentRoute(r)
		path, _ := route.GetPathTemplate()
		timer := prometheus.NewTimer(httpDuration.WithLabelValues(path))
		next.ServeHTTP(w, r)
		timer.ObserveDuration()
	})
}
