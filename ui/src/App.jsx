import logo from './logo.svg';
import './App.css';
import TodoItem from './components/TodoItem';
import { getTodos, getTodo, toggleCompleteTodo } from './todoItemService';
import React, { useState, useEffect } from 'react'
import List from '@mui/material/List';
import { ListSubheader, Grid, Box, Button } from '@mui/material';
import { DataGrid, GridRowParams } from '@mui/x-data-grid';

function App() {
  const [todoList, setTodoList] = useState([]);

  const handleToggle = (id) => {
    let mapped = todoList.map(task => {
      return task.id == id ? { ...task, completed: !task.completed } : { ...task };
    });
    setTodoList(mapped);

    // update API
    toggleCompleteTodo(id)
      .catch(error => console.log(error), (data = '[]') => console.log("data: " + data));
  }

  useEffect(() => {
    getTodos()
      .catch(error => console.log(error), (data = '[]') => console.log("data: " + data))
      .then((data) => setTodoList(data));
  }, [])

  const columns = [
    {
      field: 'id',
      headerName: 'ID',
      width: 90,
      disableClickEventBubbling: true,
    },
    {
      field: 'description',
      headerName: 'Description',
      width: 150,
      disableClickEventBubbling: true,
    },
    {
      field: 'completed',
      headerName: 'Completed',
      width: 150,
      disableClickEventBubbling: true,
      renderCell: ({ row }) =>
        <Button style={{ backgroundColor: row.completed ? "green" : "red", color: "white" }} onClick={() => handleToggle(row.id)}>
          {
            row.completed ? 'Complete' : "Incomplete"
          }
        </Button>,
    }
  ];

  return (
    <div className="App">
      <header className="App-header">
        <Box sx={{ height: '20em', width: '95%' }}>
          <DataGrid
            rows={todoList}
            columns={columns}
            pageSize={5}
            rowsPerPageOptions={[10]}
            disableSelectionOnClick
            experimentalFeatures={{ newEditingApi: true }}
          />
        </Box>
      </header>
    </div>
  );
}

export default App;
