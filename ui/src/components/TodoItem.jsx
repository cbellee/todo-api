import React, { useState } from "react";
import Box from '@mui/material/Box';
import Paper from '@mui/material/Paper';
import Grid from '@mui/material/Grid';
import ListItem from '@mui/material/ListItem';
import ListItemText from '@mui/material/ListItemText';
import { Item } from '@mui/material';
import ListItemAvatar from '@mui/material/ListItemAvatar';
import Avatar from '@mui/material/Avatar';
import { Work } from '@mui/icons-material';
import Checkbox from '@mui/material/Checkbox';
import FormGroup from '@mui/material/FormGroup';
import FormControlLabel from '@mui/material/FormControlLabel';

export default function TodoItem(todoItem) {
    const [checked, setChecked] = useState(
        new Array(todoItem.length).fill(false)
    );

    const handleOnChange = () => {
        setChecked(!checked);
    };
    return (
        <Grid item key={todoItem.todoItem.ID} className="todo stack-small">
            <ListItemText primary={todoItem.todoItem.description} secondary={todoItem.todoItem.CreatedAt} />
            <FormGroup>
                <FormControlLabel control={<Checkbox checked={checked} onChange={handleOnChange} />} label="complete" />
            </FormGroup>
        </Grid>
    );
}