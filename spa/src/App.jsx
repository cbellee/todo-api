import logo from './logo.svg';
import './App.css';
import TodoItem from './components/TodoItem';
import { getTodos, getTodo } from './todoItemService';
import React, { useState, useEffect } from 'react'

function App() {
  const [todoData, setTodoData] = useState([]);

  useEffect(() => {
    getTodos()
      .catch(error => console.log(error), (data = '[]') => console.log("data: " + data))
      .then((data) => setTodoData(data));
  }, [])

  return (
    <div className="App">
      <header className="App-header">
        <ul>
          {
           todoData.map((todo, idx) => (
              <TodoItem key={idx} todoItem={todo}></TodoItem>
            ))
          }
        </ul>
      </header>
    </div>
  );
}

export default App;
