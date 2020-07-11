import React from 'react';
import LabelModal from '../components/LabelModal';
import { ResourceState } from '../actionset';
import { connect } from 'react-redux';
import { labelset } from '../actions';

const mapStateToProps = (state, myProps) => {
  return myProps;
};

const mapDispatchToProps = (dispatch, ownProps) => {
  return {
    onLabelCreation: (label) => {
      dispatch(labelset.add({...label}));
    }
  }
};

export default connect(mapStateToProps, mapDispatchToProps)(LabelModal);
