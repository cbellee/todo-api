package models

import (
	"fmt"
	"time"

	log "github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

type TodoItemEntity struct {
	ID          uint      `gorm:"primarykey" json:"id"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
	DeletedAt   time.Time `gorm:"index" json:"deletedAt"`
	Description string    `json:"description"`
	Completed   bool      `json:"completed"`
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
		log.Warn("Todo item with state 'completed' not found in database")
		return nil, err
	}
	return todos, nil
}

func GetById(db *gorm.DB, id int) (item *TodoItemEntity, err error) {
	todo := &TodoItemEntity{}
	result := db.First(&todo, id)
	if result.Error != nil {
		log.Warn("Todo item not found in database")
		return nil, fmt.Errorf("item not found")
	}
	return todo, nil
}
