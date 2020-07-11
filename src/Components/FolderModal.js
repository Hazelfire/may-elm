import React, {Component} from 'react';

import {Modal, Header, Form, Input, Button} from 'semantic-ui-react';

export default class FolderModal extends Component {
  static defaultProps = {
    addTaskModal: false
  };

  constructor(props) {
    super(props);
    if(props.initialProperties){
      this.state = {
        ...this.props.initialProperties,
        visible: false,
      };
    }
    else{
      this.state = {
        name: "",
        visible: false,
      };
    }

    this.state.nameError = false;
  }


  nameChange = (event) => {
    let validName = event.target.value.length > 0;
    if( this.state.nameError && validName) {
      this.setState({nameError: false});
    }

    this.setState({name: event.target.value});
  };

  createFolder = () => {
    // Validation
    let foundError = false;
    if(this.state.name.length <= 0){
      this.setState({nameError: true});
      foundError = true;
    }

    if(foundError) {
      return;
    }


    let folder = {
      name: this.state.name
    };


    this.props.onModalClose(folder);
    this.closeModal();
  };

  closeModal = () => {
    this.setState({ visible: false });
  };

  openModal = () => {
    if(this.props.initialProperties){
      this.setState({
        ...this.props.initialProperties,
        visible: true
      });
    }
    else{
      this.setState({
        name: "",
        visible: true,
      });
    }
  };

  render = () => {
    return (
      <Modal
        trigger={React.cloneElement(this.props.trigger, {onClick: this.openModal})}
        onClose={this.closeModal}
        open={this.state.visible}
        size="mini"
        closeIcon
        closeOnDimmerClick={false}
      >
        <Modal.Header>{this.props.title}</Modal.Header>
        <Modal.Content>
          <Form>
            <Form.Input error={this.state.nameError} label="Name" placeholder="Name" onChange={this.nameChange} autoFocus defaultValue={this.state.name}/>
          </Form> 
        </Modal.Content>
        <Modal.Actions>
          <Button onClick={this.createFolder} color='green' inverted >{this.props.buttonText}</Button>
        </Modal.Actions>
      </Modal>
    )
  };
}
