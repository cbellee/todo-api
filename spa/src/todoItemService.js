
// let endpoint = 'https://todo-api.mangostone-42fec7f4.australiaeast.azurecontainerapps.io'
let endpoint = 'http://localhost:8080'

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