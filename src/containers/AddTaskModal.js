import React from 'react';
import TaskModal from '../components/TaskModal';
import { ResourceState } from '../actionset';
import { connect } from 'react-redux';
import { taskset, folderset, addTask } from '../actions';

const mapStateToProps = (state, myProps) => {
  return {
    title: "Add new task",
    buttonText: "Add Task",
    addTaskModal: true,
    trigger: myProps.trigger,
    tasks: myProps.tasks //new ResourceState(state.serverReducer.tasks).toList(),
  }
};

const mapDispatchToProps = (dispatch, ownProps) => {
  return {
    onModalClose: (task) => {
      let folder = ownProps.folder;
      ownProps.onAddTask({...task, parent: folder.id}));
      // dispatch(addTask({...task, parent: folder.id})); Legacy Redux
    }
  }
};

export default connect(mapStateToProps, mapDispatchToProps)(TaskModal);
