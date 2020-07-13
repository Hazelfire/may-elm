import React, {Component} from 'react'

import {Dropdown, Label, Input, Button, Icon} from 'semantic-ui-react';

import LabelModal from './LabelModal'
import ManageLabelModal from './ManageLabelModal'
import {ADD_LABEL} from '../actions'

export default class LabelSelector extends Component{
    constructor(props) {
        super(props);
        this.state = {
          selectedLabels: this.props.defaultValue ? 
          this.props.defaultValue : [],
          query: "",
          modalVisible: false,
          manageModalVisible: false,
        };
    }

    componentDidMount() {
    }

    labelAdd = (label) => {
      let newLabels = this.state.selectedLabels.concat([label]);
      this.setState({selectedLabels: newLabels});
      this.props.onChange(newLabels);
    };

    labelRemove = (label) => {
      let newLabels = this.state.selectedLabels.filter(checkLabel =>
        checkLabel.id != label.id
      );
      this.setState({selectedLabels: newLabels});
      this.props.onChange(newLabels);
    }

    labelEdit = (id, newLabel) => {
      let newLabels = this.state.selectedLabels.map(label =>
        label.id == id ? newLabel : label
      );
      this.setState({selectedLabels: newLabels});
      this.props.onChange(newLabels);
    };
    
    getValidLabels = () => {
      let selectedLabelIds = this.state.selectedLabels.map(label => label.id);
      let validLabels = this.props.labels.filter(label => {
        return !selectedLabelIds.includes(label.id) &&
          label.name.toLowerCase().startsWith(this.state.query.toLowerCase());
      });
      return validLabels;
    };

    updateSearch = (e) => {
      let query = e.target.value;
      this.setState({query: query});
    };

    closeModal = () => {
      this.setState({modalVisible: false});
    };

    closeManageModal = () => {
      this.setState({manageModalVisible: false});
    };

    render = () => {
        return (
            <div>
                <Dropdown text='Add labels' icon='tags' floating labeled button className='icon'>
                    <Dropdown.Menu>
                      <Input
                        placeholder='Search labels'
                        icon='search'
                        iconPosition='left'
                        className='search'
                        onClick={e => e.stopPropagation()}
                        onChange={e => this.updateSearch(e)}
                      />
                        <Dropdown.Divider />
                        <Dropdown.Header icon='tags' content='Select Label' />
                        <Dropdown.Menu scrolling>
                          {this.getValidLabels().length == 0 &&
                           this.state.query.length == 0 &&
                           this.state.selectedLabels.length == 0 &&
                              <Dropdown.Item
                                text='No labels! Create a new label below'
                                disabled
                              />
                          }
                          {this.getValidLabels().length == 0 &&
                           this.state.query.length == 0 &&
                           this.state.selectedLabels.length > 0 &&
                              <Dropdown.Item
                                text='No more labels! Create a new label below'
                                disabled
                              />
                          }
                          {this.getValidLabels().length == 0 &&
                           this.state.query.length > 0 &&
                              <Dropdown.Item
                                text='No labels found!'
                                disabled
                              />
                          }
                          {this.getValidLabels().length > 0 &&
                              this.getValidLabels().map(label => (
                              <Dropdown.Item
                                key={label.name}
                                label={{ color: label.color, empty: true, circular: true }}
                                text={label.name}
                                onClick={() => this.labelAdd(label)}
                              />
                          ))}
                        </Dropdown.Menu>
                        <Dropdown.Item
                          icon='plus'
                          text='Add label'
                          onClick={() => {
                            this.setState({modalVisible: true});
                          }}
                        />
                        <LabelModal
                          title='Add label'
                          buttonText='Add label'
                          open={this.state.modalVisible}
                          closeModal={this.closeModal}
                          onLabelCreation={(label) => this.props.dispatch({type: ADD_LABEL, label})}
                        />
                        {this.props.labels.length > 0 &&
                            <Dropdown.Item
                              text='Manage labels'
                              onClick={() => {
                                this.setState({manageModalVisible: true});
                              }}
                            />
                        }
                        <ManageLabelModal
                          open={this.state.manageModalVisible}
                          closeModal={this.closeManageModal}
                          removeLabelFromTask={this.labelRemove}
                          editTaskLabel={this.labelEdit}
                          labels={this.props.labels}
                          dispatch={this.props.dispatch}
                        />
                    </Dropdown.Menu>
                </Dropdown>
                {this.props.defaultValue.map(label => {
                  return (
                    label && 
                    <Label color={label.color} >
                      {label.name}
                      <Icon
                        name="delete"
                        onClick={() => this.labelRemove(label)}
                      />
                    </Label>
                  );
                })}
            </div>
        )
    }; }