
let endpoint = 'https://todolist.whitepebble-2eea549e.australiaeast.azurecontainerapps.io'
// let endpoint = 'http://localhost:8080'

export async function getTodos() {
    const response = await fetch(`${endpoint}/api/todos`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
    })
    return await response.json();
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