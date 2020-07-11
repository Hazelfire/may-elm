import React from 'react';
import LabelSelector from '../components/LabelSelector';
import { ResourceState } from '../actionset'
import {connect} from 'react-redux';
import { labelset } from '../actions';

const mapStateToProps = (state, myProps) => {
  return {
    ...myProps,
    labels: new ResourceState(state.serverReducer.labels).toList(),
  };
};

const mapDispatchToProps = (dispatch, myProps) => {
  return {
    addLabel: (label) => {
      dispatch(labelset.add({...label}));
    },
    getLabels: () => {
      dispatch(labelset.list());
    },
  };
};

export default connect(mapStateToProps, mapDispatchToProps)(LabelSelector);
