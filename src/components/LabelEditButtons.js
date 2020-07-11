import React, {Component} from 'react';

import {Button, Confirm} from 'semantic-ui-react';

import LabelModal from './LabelModal'

export default class LabelEditButtons extends Component {
  constructor(props) {
    super(props);
    this.state = {
      confirmOpen: false,
      editOpen: false,
    };
  }

  render = () => {
    return (
      <div>
        <Button
          inverted
          color='blue'
          onClick={() => this.setState({editOpen: true})}
        >
          Edit
        </Button>
        <Button
          inverted
          color='red'
          onClick={() => this.setState({confirmOpen: true})}
        >
          Delete
        </Button>

        <Confirm
          open={this.state.confirmOpen}
          header='Delete Label'
          content='Are you sure you want to delete this label?'
          confirmButton='Delete'
          onCancel={() => this.setState({confirmOpen: false})}
          onConfirm={() => this.props.deleteLabel(this.props.label)}
        />
        <LabelModal
          title='Edit label'
          buttonText='Edit label'
          open={this.state.editOpen}
          initialProperties={this.props.label}
          closeModal={() => this.setState({editOpen: false})}
          onLabelCreation={this.props.editLabel}
        /> 
    </div>
    )
  };
}
