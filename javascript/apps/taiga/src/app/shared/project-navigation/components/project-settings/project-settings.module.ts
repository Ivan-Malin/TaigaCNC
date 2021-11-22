/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { CommonModule } from '@angular/common';
import { NgModule } from '@angular/core';
import { TranslocoModule } from '@ngneat/transloco';
import { TuiButtonModule, TuiSvgModule } from '@taiga-ui/core';
import { ProjectSettingsComponent } from './project-settings.component';

@NgModule({
  imports: [
    CommonModule,
    TuiButtonModule,
    TuiSvgModule,
    TranslocoModule,
  ],
  declarations: [
    ProjectSettingsComponent,
  ],
  providers: [],
  exports: [
    ProjectSettingsComponent,
  ]
})
export class ProjectSettingsModule {}
