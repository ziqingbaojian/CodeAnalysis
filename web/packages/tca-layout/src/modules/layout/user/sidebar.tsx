import React from 'react';
import { t } from '@src/utils/i18n';
import User from 'coding-oa-uikit/lib/icon/User';
import Shield from 'coding-oa-uikit/lib/icon/Shield';
import Ticket from 'coding-oa-uikit/lib/icon/Ticket';
// 项目内
import LayoutMenu from '@src/component/layout-menu';

const SiderBar = () => <LayoutMenu
  menus={[
    {
      icon: <User className='layoutMenuItemIcon' />,
      title: t('用户信息'),
      link: '/user/profile',
      key: 'profile',
    },
    {
      icon: <Shield className='layoutMenuItemIcon' />,
      title: t('凭证管理'),
      link: '/user/auth',
      key: 'auth',
    },
    {
      icon: <Ticket className='layoutMenuItemIcon' />,
      title: t('个人令牌'),
      link: '/user/token',
      key: 'token',
    },
  ]}
/>;

export default SiderBar;
