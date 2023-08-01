
<<<<<<< HEAD
let endpoint = 'https://aca-todolist-demo.braveground-c7fa82d3.westeurope.azurecontainerapps.io'
// let endpoint = 'http://localhost:8080'
=======
let endpoint = window._env_.API_URL
>>>>>>> 0ea3854d0017fb8561d9b18d825383153df4005e

export async function getTodos() {
    const response = await fetch(`${endpoint}/api/todos`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
    })
    let r = await response.json()
    console.log("getTodos response: " + JSON.stringify(r))
    return r;
}

export async function getTodo(id) {
    const response = await fetch(`${endpoint}/api/todos/${id}`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
    })
    return await response.json();
}

export async function toggleCompleteTodo(id) {
    const response = await fetch(`${endpoint}/api/todos/complete/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
    })
    return await response.json();
}

export async function createTodo(description) {
    const response = await fetch(`${endpoint}/api/todos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: { "description": `"${description}"` },
    })
    return await response.json();
}

export async function deleteTodo(id) {
    const response = await fetch(`${endpoint}/api/todos/${id}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
    })
    return await response.json();
}

export async function updateTodo(id, description) {
    console.log(`"newRow id: ${id}`)
    console.log(`"newRow description: ${description}`)
    const response = await fetch(`${endpoint}/api/todos/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: { "description": `"${description}"` },
    })
    return await response.json();
}