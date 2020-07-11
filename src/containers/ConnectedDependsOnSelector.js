import React from 'react';
import DependsOnSelector from '../components/DependsOnSelector';
import { ResourceState } from '../actionset'
import {connect} from 'react-redux';
import { taskset } from '../actions';

const mapStateToProps = (state, myProps) => {
  return {
    ...myProps,
    tasks: new ResourceState(state.serverReducer.tasks).toList(),
  };
};

const mapDispatchToProps = (dispatch, myProps) => {
  return myProps;
};

export default connect(mapStateToProps, mapDispatchToProps)(DependsOnSelector);
