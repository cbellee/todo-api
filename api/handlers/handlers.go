package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"todo-api/models"

	log "github.com/sirupsen/logrus"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"gorm.io/driver/sqlserver"
	"gorm.io/gorm"
)

var (
	dsn = os.Getenv("DSN")

	getOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_get_total",
		Help: "total number of calls to the 'get' endpoint",
	})

	createOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_created_total",
		Help: "total number of calls to the 'create' endpoint",
	})

	updateOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_updated_total",
		Help: "total number of calls to the 'update' endpoint",
	})

	completeOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_completed_total",
		Help: "total number of calls to the 'complete' endpoint",
	})

	incompleteOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_incomplete_total",
		Help: "total number of calls to the 'incomplete' endpoint",
	})

	deleteOperationsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "todoapi_deleted_total",
		Help: "total number of calls to the 'delete' endpoint",
	})

	httpDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name: "todoapi_http_duration_seconds",
		Help: "Duration of HTTP requests.",
	}, []string{"path"})
)

type Env struct {
	Db *gorm.DB
}

func (env *Env) Readiness(w http.ResponseWriter, r *http.Request) {
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

func (env *Env) Liveness(w http.ResponseWriter, r *http.Request) {
	log.Info("API Health is OK")
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	io.WriteString(w, `{"alive": true}`)
}

func (env *Env) GetAll(w http.ResponseWriter, r *http.Request) {
	env.Db.DB()
	allTodoItems, err := models.GetAll(env.Db)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
	}
	log.Info(fmt.Printf("TodoItem count: %d\n", len(allTodoItems)))
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(allTodoItems)

	// increment Prometheus counter
	getOperationsProcessed.Inc()
}

func (env *Env) GetById(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	todoItem, err := models.GetById(env.Db, id)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
		return
	}
	log.Info("TodoItem: %v", todoItem)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(todoItem)

	// increment Prometheus counter
	getOperationsProcessed.Inc()
}

func (env *Env) GetCompleted(w http.ResponseWriter, r *http.Request) {
	log.Info("Get completed TodoItems")
	completedTodoItems, err := models.GetByCompletionStatus(env.Db, true)
	fmt.Print(completedTodoItems)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(completedTodoItems)

	// increment Prometheus counter
	completeOperationsProcessed.Inc()
}

func (env *Env) GetIncomplete(w http.ResponseWriter, r *http.Request) {
	log.Info("Get Incomplete TodoItems")
	incompleteTodoItems, err := models.GetByCompletionStatus(env.Db, false)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(incompleteTodoItems)

	// increment Prometheus counter
	incompleteOperationsProcessed.Inc()
}

func (env *Env) Create(w http.ResponseWriter, r *http.Request) {
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
	env.Db.Create(&todo)
	result := env.Db.Last(&todo)
	json.NewEncoder(w).Encode(result.RowsAffected)

	// increment Prometheus counter
	createOperationsProcessed.Inc()
}

func (env *Env) Update(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	var t models.CreateOrUpdateTodoItem

	decoder := json.NewDecoder(r.Body)
	if err := decoder.Decode(&t); err != nil {
		io.WriteString(w, `{"created: false, "error": "error marshalling JSON to todo item"}`)
	}
	defer r.Body.Close()

	if todoItem, err := models.GetById(env.Db, id); err != nil {
		io.WriteString(w, `{"updated": "false", "error": "Record Not Found"}`)
	} else {
		log.WithFields(log.Fields{"Id": id}).Info("Updating TodoItem")
		todoItem.Description = t.Description
		env.Db.Save(&todoItem)
		io.WriteString(w, `{"updated": true}`)

		// increment Prometheus counter
		updateOperationsProcessed.Inc()
	}
}

func (env *Env) Complete(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	if todoItem, err := models.GetById(env.Db, id); err != nil {
		io.WriteString(w, `{"deleted": false, "error": "Record Not Found"}`)
	} else {
		if todoItem.Completed {
			todoItem.Completed = false
		} else {
			todoItem.Completed = true
		}
		env.Db.Save(&todoItem)
		io.WriteString(w, `{"updated": true}`)

		// increment Prometheus counter
		completeOperationsProcessed.Inc()
	}
}

func (env *Env) Delete(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	if todoItem, err := models.GetById(env.Db, id); err != nil {
		io.WriteString(w, `{"deleted": "false", "error": "Record Not Found"}`)
	} else {
		log.WithFields(log.Fields{"Id": id}).Info("Delete TodoItem")
		env.Db.Delete(&todoItem)
		io.WriteString(w, `{"deleted": true}`)

		// increment Prometheus counter
		deleteOperationsProcessed.Inc()
	}
}

// prometheusMiddleware implements Gorilla Mux MiddlewareFunc
func PrometheusMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		route := mux.CurrentRoute(r)
		path, _ := route.GetPathTemplate()
		timer := prometheus.NewTimer(httpDuration.WithLabelValues(path))
		next.ServeHTTP(w, r)
		timer.ObserveDuration()
	})
}
