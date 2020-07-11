import React, {Component} from 'react';

import {Modal, Header, Form, Button, List, Label, Confirm} from 'semantic-ui-react';

import LabelEditButtons from './LabelEditButtons';
import LabelModal from './LabelModal';
import { DELETE_LABEL, EDIT_LABEL } from '../actions.js';

export default class ManageLabelModal extends Component {
  constructor(props) {
    super(props);
    this.state = {
      addLabelVisible: false,
      editLabelVisible: false,
    };
  }

  deleteLabel = (label) => {
    this.props.dispatch({
      type: DELETE_LABEL,
      label
    });
    this.props.removeLabelFromTask(label);
  };

  editLabel = (label, changes) => {
    this.props.dispatch({
      type: EDIT_LABEL,
      label,
      changes
    });
    this.props.editTaskLabel(label.id, label);
  };

  closeAddLabelModal = () => {
    this.setState({addLabelVisible: false});
  };

  closeEditLabelModal = () => {
    this.setState({editLabelVisible: false});
  };

  render = () => {
    return (
      <div>
        {this.props.open &&
        <Modal
          onClose={this.props.closeModal}
          open={this.props.open}
          closeIcon
          closeOnDimmerClick={false}
        >
          <Modal.Header>Manage Labels</Modal.Header>
          <Modal.Content>
            <List 
              relaxed='very'
              divided
              verticalAlign='middle'
            >
              {this.props.labels &&
                  this.props.labels.map(label => {
                    return (
                      <List.Item key={label.id}>
                        <List.Content floated='right'>
                          <LabelEditButtons
                            label={label}
                            deleteLabel={this.deleteLabel}
                            editLabel={(changes) => this.editLabel(label, changes)}
                          />
                        </List.Content>
                        <List.Icon
                          name='circle'
                          color={label.color}
                        />
                        <List.Content>
                          {label.name}
                        </List.Content>
                      </List.Item>
                    );
                  })
              }
              {this.props.labels &&
               this.props.labels.length == 0 &&
                  'No labels!'
              }
            </List>
          </Modal.Content>
            <Modal.Actions>
              <Button
                color='green'
                inverted
                onClick={() => this.setState({addLabelVisible: true})}
              >
                Add Label
              </Button>
            </Modal.Actions>
        </Modal>
        }
        <LabelModal
          title='Add label'
          buttonText='Add label'
          open={this.state.addLabelVisible}
          closeModal={this.closeAddLabelModal}
          dispatch={this.props.dispatch}
        />

      </div>
    )
  };
}
