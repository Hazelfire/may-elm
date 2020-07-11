import React, {Component} from 'react';

import {Modal, Header, Form, Input, Button} from 'semantic-ui-react';
import { ADD_LABEL } from '../actions';

import ColorSelector from './ColorSelector';

export default class LabelModal extends Component {
  constructor(props) {
    super(props);
    if(this.props.initialProperties) {
      this.state = {
        ...this.props.initialProperties,
        nameError: false,
        colorError: false,
      };
    }
    else {
      this.state = {
        name: '',
        color: '',
        nameError: false,
        colorError: false,
      };
    }
  }

  onFocus() {
    console.log("focus");
  }

  nameChange = (event) => {
    let validName = event.target.value.length > 0;
    if( this.state.nameError && validName) {
      this.setState({nameError: false});
    }

    this.setState({name: event.target.value});
  };

  colorChange = (event, data) => {
    let color = data.value;
    let validColor = color != '';

    if( this.state.colorError && validColor) {
      this.setState({colorError: false});
    }

    this.setState({color: color});
  }

  createLabel = () => {
    // Validation
    let foundError = false;
    if(this.state.name.length <= 0){
      this.setState({nameError: true});
      foundError = true;
    }

    if(this.state.color == ''){
      this.setState({colorError: true});
      foundError = true;
    }

    if(foundError) {
      return;
    }

    let label = {
      name: this.state.name,
      color: this.state.color,  
      id: this.state.id ? this.state.id : undefined,
    };

    this.props.onLabelCreation(label);
    this.closeModal();
  };

  closeModal = () => {
    this.setState({
      name: '',
      color: '',
      nameError: false,
      colorError: false,
    });
    this.props.closeModal();
  };

  render = () => {
    let initialLabel = this.props.initialProperties ?
      this.props.initialProperties :
      {
        name: '',
        color: '',
      };
    return (
      <div>
        {this.props.open &&
        <Modal
          onClose={this.closeModal}
          open={this.props.open}
          closeIcon
          closeOnDimmerClick={false}
        >
          <Modal.Header>{this.props.title}</Modal.Header>
          <Modal.Content>
            <Form>
              <Form.Input
                error={this.state.nameError}
                label="Name"
                placeholder="Name"
                onChange={this.nameChange}
                defaultValue={initialLabel.name}
              />
              <Form.Field
                error={this.state.colorError}
                label="Colour"
                control={ColorSelector}
                onChange={this.colorChange}
                defaultValue={initialLabel.color}
              />
            </Form> 
          </Modal.Content>
          <Modal.Actions>
            <Button onClick={this.createLabel} color='green' inverted >{this.props.buttonText}</Button>
          </Modal.Actions>
        </Modal>
        }
      </div>
    )
  };

}
