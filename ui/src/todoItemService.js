
let endpoint = 'https://todolistapp.blackbush-33096089.australiaeast.azurecontainerapps.io'
// let endpoint = 'http://localhost:8080'

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