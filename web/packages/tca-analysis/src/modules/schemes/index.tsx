// Copyright (c) 2021-2022 THL A29 Limited
//
// This source code file is made available under MIT License
// See LICENSE for details
// ==============================================================================

/**
 * 分析方案入口文件
 */
import React, { useEffect, useState } from 'react';
import { useHistory, useParams, Link } from 'react-router-dom';
import cn from 'classnames';
import { get, findIndex, isEmpty, toNumber, find } from 'lodash';
import { Tabs, Button } from 'coding-oa-uikit';

import { useStateStore } from '@src/context/store';
import Repos from '@src/components/repos';
import { getSchemeRouter, getTmplRouter } from '@src/utils/getRoutePath';
import { getSchemes, getLanguages, getTags, getSchemeBasic } from '@src/services/schemes';
import { getTmplList } from '@src/services/template';
import noDataSvg from '@src/images/no-data.svg';
import Loading from '@src/components/loading';

import List from './list';
import CreateSchemeModal from './create-scheme';
import BaseInfo from './baseinfo';
import CodeLint from './code-lint';
import CodeMetrics from './code-metrics';
import PathFilter from './path-filter';
import Branchs from './branchs';
import PullModal from './pull-tmpl-modal';

import style from './style.scss';

const { TabPane } = Tabs;

const Schemes = () => {
  const history = useHistory();
  const params: any = useParams();

  const { curRepo } = useStateStore();
  const [schemes, setSchemes] = useState([]);
  const [schemesLoading, setSchemesLoading] = useState(false);
  const [schemeInfo, setSchemeInfo] = useState({}) as any;
  const [visible, setVisible] = useState(false);
  const [tags, setTags] = useState([]);
  const [languages, setLanguages] = useState([]);
  const [templates, setTemplates] = useState([]);
  const [pullModalVsb, setPullModalVsb] = useState(false);

  const tab = params.tabs || 'basic';
  const schemeId = toNumber(params.schemeId);
  const { orgSid, teamName } = params;

  useEffect(() => {
    getCommonData();
  }, []);

  useEffect(() => {
    if (curRepo.id) {
      history.replace(`${getSchemeRouter(orgSid, teamName, curRepo.id, schemeId)}`);

      (async () => {
        getSchemeList(schemeId);
      })();
    }
  }, [curRepo.id]);

  const getCommonData = async () => {
    setTags(get(await getTags(orgSid), 'results', []));
    setLanguages(get(await getLanguages(), 'results', []));
    setTemplates(get(await getTmplList(orgSid, { limit: 100 }), 'results', []));
  };

  const getSchemeList = async (schemeId?: string | number) => {
    setSchemesLoading(true);
    let res = await getSchemes(orgSid, teamName, curRepo.id, { limit: 1000 });
    res = res.results || [];
    setSchemes(res);
    setSchemesLoading(false);

    const defaultScheme = find(res, { default_flag: true, status: 1 }) || {};

    const id = schemeId || defaultScheme.id || get(res, '[0].id');
    getSchemeInfo(id);
  };

  const getSchemeInfo = async (schemeId: string | number) => {
    if (schemeId) {
      const res = await getSchemeBasic(orgSid, teamName, curRepo.id, schemeId);
      history.replace(`${getSchemeRouter(orgSid, teamName, curRepo.id, schemeId)}/basic`);
      setSchemeInfo(res);
    }
  };

  return (
    <div className={style.scheme}>
      <Repos
        callback={(repo: any) => history.push(getSchemeRouter(orgSid, teamName, repo.id))}
      />
      {/* eslint-disable-next-line */}
      {schemesLoading ? (
        <Loading />
      ) : isEmpty(schemes) ? (
        <div className={style.noData}>
          <img src={noDataSvg} />
          <div>
            暂无方案，请
                        <Button type="link" onClick={() => setVisible(true)}>
              新建分析方案
                        </Button>
          </div>
        </div>
      ) : (
            <div className={style.schemeContainer}>
              <List
                repoId={curRepo.id}
                scheme={schemeInfo}
                schemeList={schemes}
                addSchemeHandle={() => {
                  setVisible(true);
                }}
                changeSchemeHandle={(item) => {
                  getSchemeInfo(item.id);
                }}
              />
              <div className={style.schemeRight}>
                <div style={{ marginBottom: 20 }}>
                  <div className={style.header}>
                    <p className={style.title}>{schemeInfo.name}</p>
                    {schemeInfo.default_flag && schemeInfo.status === 1 && (
                      <span className={style.label}>Default</span>
                    )}
                    {schemeInfo.status === 2 && (
                      <span className={cn(style.label, style.deprecatedLabel)}>
                        已废弃
                      </span>
                    )}
                  </div>
                  {schemeInfo.refer_scheme?.is_template && (
                    <p className={style.tmplDesc}>
                      该分析方案由模板
                      <Link
                        to={`${getTmplRouter(orgSid, teamName)}/${schemeInfo.refer_scheme.id
                        }`}
                        target="_blank"
                      >
                        「{schemeInfo.refer_scheme.name}」
                                    </Link>
                                    创建；若需同步模板配置，请点击
                      <Button type="link" onClick={() => setPullModalVsb(true)}>
                        同步
                                    </Button>
                    </p>
                  )}
                </div>
                <Tabs
                  activeKey={tab}
                  className={style.tabs}
                  onChange={(key) => {
                    history.push(`${getSchemeRouter(
                      orgSid,
                      teamName,
                      curRepo.id,
                      schemeInfo.id,
                    )}/${key}`);
                  }}
                >
                  <TabPane tab="基础属性" key="basic">
                    <BaseInfo
                      orgSid={orgSid}
                      teamName={teamName}
                      data={schemeInfo}
                      repoId={curRepo.id}
                      tags={tags}
                      languages={languages}
                      callback={(data: any) => {
                        let list: any = [...schemes];
                        const index = findIndex(schemes as any, { id: data.id });
                        if (index > -1) {
                          list[index] = data;
                          if (data.default_flag) {
                            list = list.map((item: any) => (item.id === data.id
                              ? data
                              : { ...item, default_flag: false }));
                          }
                          setSchemes(list);
                          setSchemeInfo(data);
                        }
                      }}
                    />
                  </TabPane>
                  <TabPane tab="代码检查" key="codelint">
                    <CodeLint
                      orgSid={orgSid}
                      teamName={teamName}
                      repoId={curRepo.id}
                      schemeId={schemeInfo.id}
                      languages={languages}
                      schemeInfo={schemeInfo}
                    />
                  </TabPane>
                  <TabPane tab="代码度量" key="codemetric">
                    <CodeMetrics
                      orgSid={orgSid}
                      teamName={teamName}
                      repoId={curRepo.id}
                      schemeId={schemeInfo.id}
                    />
                  </TabPane>
                  <TabPane tab="过滤配置" key="filters">
                    <PathFilter
                      orgSid={orgSid}
                      teamName={teamName}
                      repoId={curRepo.id}
                      schemeId={schemeInfo.id}
                    />
                  </TabPane>
                  {/* <TabPane tab="权限配置" key="perms">
                                            权限配置
                                        </TabPane> */}
                  <TabPane tab="已关联分支" key="branchs">
                    <Branchs
                      orgSid={orgSid}
                      teamName={teamName}
                      repoId={curRepo.id}
                      schemeId={schemeInfo.id}
                    />
                  </TabPane>
                </Tabs>
              </div>
            </div>
      )}
      <CreateSchemeModal
        orgSid={orgSid}
        teamName={teamName}
        visible={visible}
        tags={tags}
        languages={languages}
        schemeList={schemes}
        repoId={curRepo.id}
        templates={templates}
        onClose={() => {
          setVisible(false);
        }}
        callback={(id) => {
          getSchemeList(id);
        }}
      />
      <PullModal
        orgSid={orgSid}
        teamName={teamName}
        repoId={curRepo.id}
        schemeId={schemeInfo.id}
        visible={pullModalVsb}
        onClose={() => setPullModalVsb(false)}
        callback={(id: number | string) => {
          getSchemeInfo(id);
        }}
      />
    </div>
  );
};
export default Schemes;
