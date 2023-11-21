import logo from './logo.svg';
import './App.css';
import TodoItem from './components/TodoItem';
import { getTodos, getTodo, toggleCompleteTodo, createTodo, deleteTodo, updateTodo } from './todoItemService';
import React, { useState, useEffect, useCallback } from 'react'
import { Box, Button } from '@mui/material';
import { DataGrid, } from '@mui/x-data-grid';

function App() {
  const [todoList, setTodoList] = useState([]);
  const [editRowData, setEditRowData] = useState({})
  const [editRowsModel, setEditRowsModel] = useState({})
  const [promiseArguments, setPromiseArguments] = useState(null);

  const handleToggle = (id) => {
    let mapped = todoList.map(task => {
      return task.id == id ? { ...task, completed: !task.completed } : { ...task };
    });
    setTodoList(mapped);

    // update API
    toggleCompleteTodo(id)
      .catch(error => console.log(error), (data = '[]') => console.log("data: " + data));
  }

  const handleCreate = (description) => {
    createTodo(description)
      .catch(error => console.log(error), (data = '{}') => console.log("data: " + data))
      .then((data) => setTodoList(data));
  }

  const handleUpdate = (id, description) => {
    updateTodo(id, description)
      .then((data) => console.log("handleUpdate: " + data))
      .catch(error => console.log(error), (data = '{}') => console.log("data: " + data));
  }

  const handleProcessRowUpdate = (newRow, oldRow) => {
    updateTodo(newRow.id, newRow.description)
      .then((data) => console.log("handleUpdate: " + data))
      .catch(error => console.log(error), (data = '{}') => console.log("data: " + data));
  }

  const handleRowEditCommit = useCallback((model) => {
    console.log(`"model: ${model}"`)
    const rowId = model;

    // user stops editing when the edit model is empty
    if (model.length === 0) {
      alert(JSON.stringify(`"rowId: ${rowId}"`, null, 4));
      // update API
    } else {
      setEditRowData(model);
    }

    setEditRowsModel(model);
  }, [editRowData]
  );

  const onProcessRowUpdateError = useCallback((error) => {
    console.error(error);
    if (promiseArguments) {
      promiseArguments.reject();
      setPromiseArguments(null);
    }
  });

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
      editable: true,
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
    },
    {
      field: 'update',
      headerName: 'Update',
      width: 150,
      disableClickEventBubbling: true,
      renderCell: ({ row }) =>
        <Button style={{ backgroundColor: "blue", color: "white" }} onClick={() => handleUpdate(row.id, row.description)}>
          {
            'Update'
          }
        </Button>,
    }
  ];

  return (
    <div className="App">
      <header className="App-header">
        <Box sx={{ height: '20em', width: '80%' }}>
          <DataGrid
            rows={todoList}
            columns={columns}
            pageSize={10}
            editMode="row"
            rowsPerPageOptions={[10]}
            disableSelectionOnClick
            experimentalFeatures={{ newEditingApi: true }}
            processRowUpdate={handleProcessRowUpdate}
            onProcessRowUpdateError={onProcessRowUpdateError}
            //onRowEditCommit={handleRowEditCommit}
          />
        </Box>
      </header>
    </div>
  );
}

export default App;
