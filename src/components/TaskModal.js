import React, {Component} from 'react';

import {Modal, Header, Form, Input, Button} from 'semantic-ui-react';

import DependsOnSelector from './DependsOnSelector'
import NullableDateSelector from './NullableDateSelector'
import LabelSelector from './LabelSelector'

import { ResourceState } from '../actionset'

export default class TaskModal extends Component {
    static defaultProps = {
        addTaskModal: false
    };

    constructor(props) {
        super(props);
        this.state = {
            nameError: false,
            durationError: false
        };
    }


    dateChange = (date) => {
        this.setState({due: date});
    };

    nameChange = (event) => {
        let validName = event.target.value.length > 0;
        if( this.state.nameError && validName) {
            this.setState({nameError: false});
        }

        this.setState({name: event.target.value});
    };

    durationChange = (event) => {
        if(!isNaN(parseFloat(this.state.duration))){
            this.setState({durationError: false});
        }
        this.setState({duration: event.target.value});
    };

    createTask = () => {
        // Validation
        let foundError = false;
        if(this.state.name.length <= 0){
            this.setState({nameError: true});
            foundError = true;
        }
        
        if(isNaN(parseFloat(this.state.duration))){
            this.setState({durationError: true});
            foundError = true;
        }

        if(foundError) {
            return;
        }


        let task = {
          name: this.state.name,
          duration: parseFloat(this.state.duration),
          dependencies: this.state.dependencies.map((dependency) => dependency.id),
          labels: this.state.labels.map(label => label.id),
          due: this.state.due
        };
        

        this.props.onModalClose(task);
        this.closeModal();
    };

    closeModal = () => {
        this.setState({ visible: false });
    };
    
    openModal = () => {
        if(this.props.initialProperties){
            this.setState({
                ...this.props.initialProperties,
                visible: true,
                labels: this.props.initialProperties.labels.filter(label => 
                  label
                ),
            });
        }
        else{
            this.setState({
                due: null,
                name: "",
                duration: "",
                visible: true,
                labels: [],
                dependencies: []
            });
        }

        this.state.nameError = false;
        this.state.durationError = false;
    };

    removeDeletedLabels = () => {
      if(this.state.labels) {
        let newLabels = this.state.labels.filter(label => 
          label
        );
        this.setState({labels: newLabels});
      }
    };

    dependencyChange = (dependencies) => {
        this.setState({ dependencies: dependencies });
    };

    labelChange = (labels) => {
        this.setState({ labels: labels });
    };

    render = () => {
        return (
            <Modal
                trigger={React.cloneElement(this.props.trigger, {onClick: this.openModal})}
                onClose={this.closeModal}
                open={this.state.visible}
                closeIcon
                size="mini"
                closeOnDimmerClick={false}
            >
                <Modal.Header>{this.props.title}</Modal.Header>
                <Modal.Content>
                  <Form>
                      <Form.Input error={this.state.nameError} label="Title" placeholder="Title" onChange={this.nameChange} defaultValue={this.state.name} autoFocus/>
                      <Form.Field error={this.state.durationError}>
                          <label>Duration</label>
                          <Input placeholder="Duration" onChange={this.durationChange} defaultValue={this.state.duration} label={{basic: true, content: 'hours'}} labelPosition="right" />
                      </Form.Field>
                      <Form.Field label="Due date" control={NullableDateSelector} defaultValue={this.state.due} onChange={this.dateChange} />
                      <Form.Field label="Dependencies" control={DependsOnSelector} onChange={this.dependencyChange} defaultValue={this.state.dependencies} tasks={this.props.tasks}/>
                      <Form.Field
                        label="Labels"
                        control={LabelSelector}
                        onChange={this.labelChange}
                        defaultValue={this.state.labels}
                        labels={this.props.labels}
                        dispatch={this.props.dispatch}
                      />
                </Form> 
                </Modal.Content>
                <Modal.Actions>
                    <Button onClick={this.createTask} color='green' inverted >{this.props.buttonText}</Button>
                </Modal.Actions>
            </Modal>
        )
    };

}
    
