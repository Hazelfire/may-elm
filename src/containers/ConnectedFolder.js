import React from 'react';
import Folder from '../components/Folder';
import { ResourceState } from '../actionset';
import { connect } from 'react-redux';
import { select, setFolder, folderset, taskset } from '../actions';
import { getFoldersInFolder, getTasksInFolder } from '../selectors';

const recursiveGetTasksInFolder = (folderId, state) => {
  let tasks = getTasksInFolder(folderId, state);
  let subFolders = getFoldersInFolder(folderId, state);

  for (let i in subFolders) {
    tasks = tasks.concat(recursiveGetTasksInFolder(subFolders[i].id, state));
  }
  return tasks;
};

const mapStateToProps = (state, myProps) => {
  return {
    ...myProps,
    selected: state.serverReducer.selected == myProps.folder.id,
    getAllTasks: () => recursiveGetTasksInFolder(myProps.folder.id, state),
  };
};

const mapDispatchToProps = (dispatch, ownProps) => {
  return {
    onDelete: () => {
      let folder = ownProps.folder;
      dispatch(folderset.delete(folder.id));
    },
    onEdit: changes => {
      dispatch(folderset.edit(ownProps.folder.id, changes));
    },
    onOpen: () => {
      dispatch(setFolder(ownProps.folder.id));
    },
    onMove: id => {
      dispatch(folderset.edit(ownProps.folder.id, { parent: id }));
    },
    onSelect: () => {
      dispatch(select(ownProps.folder.id));
    },
    onDeleteTask: task => {
      dispatch(taskset.delete(task.id));
    },
  };
};

export default connect(
  mapStateToProps,
  mapDispatchToProps
)(Folder);
