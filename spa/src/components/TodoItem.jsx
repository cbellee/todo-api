import React from "react";

export default function TodoItem(todoItem) {
    return (
        <li key={todoItem.todoItem.ID} className="todo stack-small">
            <div className="c-cb">
                <input id="todo-0" type="checkbox" defaultChecked={true} />
                <label className="todo-label" htmlFor="todo-0">
                    {todoItem.todoItem.description}
                </label>
            </div>
            <div className="btn-group">
                <button type="button" className="btn">
                    Edit <span className="visually-hidden"></span>
                </button>
                <button type="button" className="btn btn__danger">
                    Delete <span className="visually-hidden"></span>
                </button>
            </div>
        </li>
    );
}