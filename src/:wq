import React, { Component } from 'react';

import { Modal, Header, Form, Input, Button } from 'semantic-ui-react';

import FolderSelector from './FolderSelector';

export default class MoveModal extends Component {
  constructor(props) {
    super(props);
    this.state = {
      visible: false,
    };
  }

  closeModal = () => {
    this.setState({ visible: false });
  };

  openModal = () => {
    if (this.props.initialProperties) {
      this.setState({
        visible: true,
      });
    } else {
      this.setState({
        visible: true,
      });
    }
  };

  moveItem = folder => {
    this.closeModal();
    this.props.onModalClose(folder);
  };

  render = () => {
    return (
      <Modal
        trigger={React.cloneElement(this.props.trigger, {
          onClick: this.openModal,
        })}
        onClose={this.closeModal}
        open={this.state.visible}
        size="mini"
        closeIcon
      >
        <Modal.Header>Move</Modal.Header>
        <Modal.Content>
          <FolderSelector
            onChange={this.moveItem}
            exclude={this.props.exclude}
            folders={this.props.folders}
          />
        </Modal.Content>
      </Modal>
    );
  };
}
