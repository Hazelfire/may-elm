import React from 'react';
import Task from '../components/Todo';
import { ResourceState } from '../actionset';
import { connect } from 'react-redux';
import { taskset, setFolder, select } from '../actions';

const mapStateToProps = (state, myProps) => {
  return {
    ...myProps,
    tasks: new ResourceState(state.serverReducer.tasks).toList(),
    selected: state.serverReducer.selected == myProps.task.id,
  };
};

const mapDispatchToProps = (dispatch, ownProps) => {
  return {
    onDelete: () => {
      dispatch(taskset.delete(ownProps.task.id));
    },
    onEdit: (changes) => {
      dispatch(taskset.edit(ownProps.task.id, changes));
    },
    onMove: (id) => {
      dispatch(taskset.edit(ownProps.task.id, {parent: id}));
    },
    onDoneStateChanged: () => {
      dispatch(taskset.edit(ownProps.task.id, {done: !ownProps.task.done}));
    },
    onSelectTask: (task) => {
      dispatch(setFolder(task.parent));
      dispatch(select(task.id));
    },
    onSelect: () => {
      dispatch(select(ownProps.task.id));
    }
  }
};

export default connect(mapStateToProps, mapDispatchToProps)(Task);
