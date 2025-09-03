import { generateOptions } from '@tencent/micro-frontend-shared/util';

export enum PkgStatusEnum {
  RUNNING = 1,
  TESTING,
  HIDDEN,
  DISABLED = 9,
}

export const PKG_STATUS_CHOICES = {
  [PkgStatusEnum.RUNNING]: '正常运营',
  [PkgStatusEnum.TESTING]: '测试中',
  [PkgStatusEnum.HIDDEN]: '隐藏中',
  [PkgStatusEnum.DISABLED]: '已禁用',
};

export const PKG_STATUS_OPTIONS = generateOptions(PKG_STATUS_CHOICES, true);
