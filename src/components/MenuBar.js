import React, {Component} from 'react';

import {Menu} from 'semantic-ui-react';

export default class MenuBar extends Component {
    constructor(props) {
        super(props);
    }

    render = () => {
        return (
            <Menu>
                <Menu.Item
                    name='logout'
                    position='right'
                    onClick={() => this.props.logout()}
                >
                    Logout
                </Menu.Item>
            </Menu>
        )
    }
}
