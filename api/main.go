package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/gorilla/mux"
	log "github.com/sirupsen/logrus"

	models "todo-api/models"

	"github.com/rs/cors"
	"gorm.io/driver/sqlite"
	"gorm.io/driver/sqlserver"
	"gorm.io/gorm"
)

var (
	dsn = os.Getenv("DSN")
)

type Env struct {
	db *gorm.DB
}

func main() {
	env := &Env{db: nil}

	if strings.TrimSpace(dsn) == "" {
		log.Info("using local in memory SQLite database")
		db, err := gorm.Open(sqlite.Open("file:memdb1?mode=memory&cache=shared"), &gorm.Config{})
		if err != nil {
			log.Errorf("Failed to open local db with error: %v", err)
		}
		env = &Env{db: db}
	} else {
		log.Info("using Azure SQL database")
		db, err := gorm.Open(sqlserver.Open(dsn), &gorm.Config{})
		if err != nil {
			log.Errorf("Failed to open remote db with error: '%v'", err)
		}
		env = &Env{db: db}
	}

	env.db.Migrator().AutoMigrate(&models.TodoItemEntity{})
	funcPrefix := "/api"
	listenAddr := ":8080"

	log.Info("Starting ToDoList API Server")

	router := mux.NewRouter()
	router.HandleFunc(fmt.Sprintf("%s/healthz/liveness", funcPrefix), healthz).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos", funcPrefix), env.getAll).Methods("GET")
	//router.HandleFunc(fmt.Sprintf("%s/todos/completed", funcPrefix), env.getCompleted).Methods("GET")
	//router.HandleFunc(fmt.Sprintf("%s/todos/incomplete", funcPrefix), env.getIncomplete).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos/{id}", funcPrefix), env.getById).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos", funcPrefix), env.create).Methods("POST")
	router.HandleFunc(fmt.Sprintf("%s/todos/{id}", funcPrefix), env.update).Methods("PATCH")
	router.HandleFunc(fmt.Sprintf("%s/todos/complete/{id}", funcPrefix), env.complete).Methods("PATCH")
	router.HandleFunc(fmt.Sprintf("%s/todos/{id}", funcPrefix), env.delete).Methods("DELETE")

	handler := cors.New(cors.Options{
		AllowedMethods: []string{"GET", "POST", "DELETE", "PATCH", "OPTIONS"},
	}).Handler(router)

	http.ListenAndServe(listenAddr, handler)
}

func healthz(w http.ResponseWriter, r *http.Request) {
	// test SQL connection only if using a remote database
	if strings.TrimSpace(dsn) != "" {
		_, err := gorm.Open(sqlserver.Open(dsn), &gorm.Config{})
		if err != nil {
			log.Fatalf("Failed to open db with error: %v", err)
			log.Info("API Health is degraded")
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			io.WriteString(w, fmt.Sprintf(`{"alive": false, "error": %s}`, err))
		}
	} else {
		log.Info("API Health is OK")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		io.WriteString(w, `{"alive": true}`)
	}
}

func init() {
	log.SetFormatter(&log.TextFormatter{})
	log.SetReportCaller(true)
}

func (env *Env) getAll(w http.ResponseWriter, r *http.Request) {
	allTodoItems, err := models.GetAll(env.db)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
	}
	log.Info(fmt.Printf("TodoItem count: %d\n", len(allTodoItems)))
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(allTodoItems)
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
}

/* func (env *Env) getCompleted(w http.ResponseWriter, r *http.Request) {
	log.Info("Get completed TodoItems")
	completedTodoItems, err := models.GetByCompletionStatus(env.db, true)
	fmt.Print(completedTodoItems)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(completedTodoItems)
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
} */

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
	}

	log.WithFields(log.Fields{"description": t.Description}).Info("Add new TodoItem. Saving to database...")
	todo := &models.TodoItemEntity{Description: t.Description, Completed: false}
	env.db.Create(&todo)
	result := env.db.Last(&todo)
	json.NewEncoder(w).Encode(result.RowsAffected)
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
	}
}

func (env *Env) complete(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	if todoItem, err := models.GetById(env.db, id); err != nil {
		io.WriteString(w, `{"deleted": false, "error": "Record Not Found"}`)
	} else {
		todoItem.Completed = true
		env.db.Save(&todoItem)
		io.WriteString(w, `{"updated": true}`)
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
	}
}
