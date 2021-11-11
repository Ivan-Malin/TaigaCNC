/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';

import { ProjectPageComponent } from './project-page.component';
import { ProjectPageRoutingModule } from './project-page-routing.module';
import { ProjectNavigationModule } from '~/app/shared/project-navigation/project-navigation.module';
import { ProjectModule } from '~/app/features/project/project/project.module';
import { TranslocoModule } from '@ngneat/transloco';
import { AvatarModule } from '@taiga/ui/avatar';

@NgModule({
  declarations: [
    ProjectPageComponent
  ],
  imports: [
    CommonModule,
    ProjectPageRoutingModule,
    ProjectNavigationModule,
    ProjectModule,
    TranslocoModule,
    AvatarModule
  ]
})
export class ProjectPageModule { }