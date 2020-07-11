import React, {Component} from 'react'

import {List, Dropdown, Button} from 'semantic-ui-react';

export default class DependsOnSelector extends Component{
    constructor(props) {
        super(props);
        this.state = {
            listedDependencies: this.props.defaultValue? this.props.defaultValue : [],
            chosenTask: null
        }
    }

    dependencyChosen = (event, data) => {
        let task = data.value;
        this.setState({chosenTask: task});
    }

    dependencyAdd = (event, data) => {
        let task = data.value;
        let newDependencies = this.state.listedDependencies.concat([task]);
        this.setState({listedDependencies: newDependencies, chosenTask: null});
        this.props.onChange(newDependencies);
    }

    getValidDependencies = () => {
        let dependencyNames = this.state.listedDependencies.map(task => task.name);
        let validDependencies = this.props.tasks.filter(task => {
            return !dependencyNames.includes(task.name) &&
                   (!this.props.initialProperties ||
                        task.name != this.props.initialProperties.name);
        });
        return validDependencies;
    };

    deleteDependency = (index) => {
        let newDependencies = [...this.state.listedDependencies];
        newDependencies.splice(index, 1);
        this.setState({listedDependencies: newDependencies, chosenTask: null});
        this.props.onChange(newDependencies);
    }


    render = () => {
        let dependencies = this.state.listedDependencies;
        let options = this.getValidDependencies().map((task, i) => { return {key: i, value: task, text: task.name}})
        return (
            <div>
                <List>
                    {dependencies.map((dependency, i) => (
                        <List.Item key={i}>
                            <List.Content floated='left'>{dependency.name}</List.Content>
                            <List.Content floated='right'>
                                <Button onClick={()=>this.deleteDependency(i)}>Delete</Button>
                            </List.Content>
                        </List.Item>
                    ))}
                    <List.Item key={dependencies.length}>
                        <List.Content floated='left'>
                            <Dropdown placeholder='Add dependency' search selection options={options} onChange={this.dependencyAdd} 
                                selectOnBlur={false} />
                        </List.Content>
                    </List.Item>
                </List>
            </div>
        );
    }
}
