import React, { Component } from 'react';
import { List, Icon } from 'semantic-ui-react';

export default class FolderSelector extends Component{
  
  renderChildren(folder){
    let folders = this.props.folders;
    let exclude = this.props.exclude;
    let childFolders = folders.filter((possibleChild) => possibleChild.parent == folder.id);
    return (
      <List.List>
        {childFolders.filter((child) => child.id != exclude).map((child) => 
          <List.Item key={child.id} >
            <Icon name="folder" />
            <List.Content>
              <List.Header as='a' onClick={() => this.props.onChange(child)}>{child.name}</List.Header>
              {this.renderChildren(child)}
            </List.Content>
          </List.Item>
        )}
      </List.List>
    );
  }

  render() {
    let folders = this.props.folders;
    let root = folders.find((folder) => folder.root);
    return (
      <List>
        <List.Item>
          <Icon name="folder" />
          <List.Content>
            <List.Header as='a' onClick={() => this.props.onChange(root)}>{root.name}</List.Header>
            {this.renderChildren(root)}
          </List.Content>
        </List.Item>
      </List>
    );
  }
}
