import React from 'react';
import TaskModal from '../components/TaskModal';
import { ResourceState } from '../actionset';
import { connect } from 'react-redux';
import { taskset, folderset } from '../actions';

const mapStateToProps = (state, myProps) => {
  return {
    ...myProps
    tasks: new ResourceState(state.serverReducer.tasks).toList(),
  }
};

const mapDispatchToProps = (dispatch, ownProps) => {
  return {
    onModalClose: (task) => {
      let folder = ownProps.folder;
      dispatch(taskset.add({...task, parent: folder.id}));
    },
    onOpen: ownProps.onOpen,
  }
};

export default connect(mapStateToProps, mapDispatchToProps)(TaskModal);
