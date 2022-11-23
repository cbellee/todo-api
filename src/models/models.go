package models

import (
	"gorm.io/gorm"
	log "github.com/sirupsen/logrus"
)

type TodoItemEntity struct {
	gorm.Model
	Description string `json:"description"`
	Completed   bool   `json:"completed"`
}

type CreateOrUpdateTodoItem struct {
	Description string `json:"description"`
}

type CompleteTodoItem struct {
	Completed bool `json:"completed"`
}

func GetAll(db *gorm.DB) (items []TodoItemEntity, err error) {
	var todos []TodoItemEntity
	err = db.Find(&todos).Error
	if err != nil {
		return nil, err
	}

	return todos, nil
}

func GetByCompletionStatus(db *gorm.DB, completed bool) (items []TodoItemEntity, err error) {
	var todos []TodoItemEntity
	err = db.Where("completed = ?", completed).Find(&todos).Error
	if err != nil {
		return nil, err
	}

	return todos, nil
}

func GetItemById(db *gorm.DB, id int) bool {
	todo := &TodoItemEntity{}
	result := db.First(&todo, id)
	if result.Error != nil {
		log.Warn("Todo item not found in database")
		return false
	}
	
	return true
}
