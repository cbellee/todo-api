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

	"github.com/rs/cors"
	"gorm.io/driver/sqlite"
	"gorm.io/driver/sqlserver"
	"gorm.io/gorm"
	models "todo-api/models"
)

type Env struct {
	db *gorm.DB
}

func main() {
	dsn := os.Getenv("DSN")
	env := &Env{db: nil}

	if strings.TrimSpace(dsn) == "" {
		log.Info("using local in memory SQLite database")
		log.Infof("connection string: '%s'", dsn)

		db, err := gorm.Open(sqlite.Open("file:memdb1?mode=memory&cache=shared"), &gorm.Config{})
		if err != nil {
			log.Errorf("Failed to open local db: %v", err)
		}
		env = &Env{db: db}
	} else {
		log.Info("using Azure SQL database")
		log.Infof("connection string: '%s'", dsn)

		db, err := gorm.Open(sqlserver.Open(dsn), &gorm.Config{})
		if err != nil {
			log.Errorf("Failed to open remote db with connection string: '%s' \n error: '%v'", dsn, err)
		}
		env = &Env{db: db}
	}

	env.db.Migrator().AutoMigrate(&models.TodoItemEntity{})
	funcPrefix := "/api"
	listenAddr := ":8080"

	log.Info("Starting ToDoList API Server")

	router := mux.NewRouter()
	router.HandleFunc(fmt.Sprintf("%s/healthz", funcPrefix), healthz).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos", funcPrefix), env.get).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos/completed", funcPrefix), env.getCompleted).Methods("GET")
	router.HandleFunc(fmt.Sprintf("%s/todos/incomplete", funcPrefix), env.getIncomplete).Methods("GET")
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
	log.Info("API Health is OK")
	w.Header().Set("Content-Type", "application/json")
	io.WriteString(w, `{"alive": true}`)
}

func init() {
	log.SetFormatter(&log.TextFormatter{})
	log.SetReportCaller(true)
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

	if err := models.GetItemById(env.db, id); !err {
		io.WriteString(w, `{"updated": "false", "error": "Record Not Found"}`)
	} else {
		log.WithFields(log.Fields{"Id": id}).Info("Updating TodoItem")
		todo := &models.TodoItemEntity{}
		env.db.First(&todo, id)
		todo.Description = t.Description
		env.db.Save(&todo)
		io.WriteString(w, `{"updated": true}`)
	}
}

func (env *Env) complete(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	if err := models.GetItemById(env.db, id); !err {
		io.WriteString(w, `{"deleted": false, "error": "Record Not Found"}`)
	} else {
		todo := &models.TodoItemEntity{}
		env.db.First(&todo, id)
		todo.Completed = true
		env.db.Save(&todo)
		io.WriteString(w, `{"updated": true}`)
	}
}

func (env *Env) delete(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	if err := models.GetItemById(env.db, id); !err {
		io.WriteString(w, `{"deleted": "false", "error": "Record Not Found"}`)
	} else {
		log.WithFields(log.Fields{"Id": id}).Info("Delete TodoItem")
		todo := &models.TodoItemEntity{}
		env.db.First(&todo, id)
		env.db.Delete(&todo)
		io.WriteString(w, `{"deleted": true}`)
	}
}

func (env *Env) get(w http.ResponseWriter, r *http.Request) {
	allTodoItems, err := models.GetAll(env.db)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(err)
	}
	log.Info("Get all TodoItems count: %d", allTodoItems)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(allTodoItems)
}

func (env *Env) getCompleted(w http.ResponseWriter, r *http.Request) {
	log.Info("Get completed TodoItems")
	completedTodoItems, err := models.GetByCompletionStatus(env.db, true)
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
}
