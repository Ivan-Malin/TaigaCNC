/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { createFeature, createReducer, on } from '@ngrx/store';
import { Workflow, Status } from '@taiga/data';
import { immerReducer } from '~/app/shared/utils/store';
import {
  KanbanActions,
  KanbanApiActions,
  KanbanEventsActions,
} from '../actions/kanban.actions';

import { Task } from '@taiga/data';

import {
  KanbanTask,
  PartialTask,
} from '~/app/modules/project/feature-kanban/kanban.model';

export interface KanbanState {
  loadingWorkflows: boolean;
  loadingTasks: boolean;
  workflows: null | Workflow[];
  tasks: Record<Status['slug'], KanbanTask[]>;
  createTaskForm: Status['slug'];
  scrollToTask: PartialTask['tmpId'][];
  empty: boolean | null;
  newEventTasks: Task['reference'][];
}

export const initialKanbanState: KanbanState = {
  loadingWorkflows: false,
  loadingTasks: false,
  workflows: null,
  tasks: {},
  createTaskForm: '',
  scrollToTask: [],
  empty: null,
  newEventTasks: [],
};

export const reducer = createReducer(
  initialKanbanState,
  on(KanbanActions.initKanban, (state): KanbanState => {
    state.workflows = null;
    state.tasks = {};
    state.loadingWorkflows = true;
    state.loadingTasks = true;
    state.scrollToTask = [];
    state.createTaskForm = '';
    state.empty = null;

    return state;
  }),
  on(KanbanActions.openCreateTaskForm, (state, { status }): KanbanState => {
    state.createTaskForm = status;

    return state;
  }),
  on(KanbanActions.closeCreateTaskForm, (state): KanbanState => {
    state.createTaskForm = '';

    return state;
  }),
  on(KanbanActions.createTask, (state, { task }): KanbanState => {
    if ('tmpId' in task) {
      state.scrollToTask.push(task.tmpId);
    }

    state.tasks[task.status].push(task);

    return state;
  }),
  on(
    KanbanApiActions.fetchWorkflowsSuccess,
    (state, { workflows }): KanbanState => {
      state.workflows = workflows;
      state.loadingWorkflows = false;

      workflows.forEach((workflow) => {
        workflow.statuses.forEach((status) => {
          if (!state.tasks[status.slug]) {
            state.tasks[status.slug] = [];
          }
        });
      });

      if (state.empty !== null && state.empty) {
        // open the first form if the kanban is empty
        state.createTaskForm = state.workflows[0].statuses[0].slug;
      }

      return state;
    }
  ),
  on(
    KanbanApiActions.fetchTasksSuccess,
    (state, { tasks, offset }): KanbanState => {
      tasks.forEach((task) => {
        if (!state.tasks[task.status]) {
          state.tasks[task.status] = [];
        }

        state.tasks[task.status].push(task);
      });

      state.loadingTasks = false;

      if (!offset) {
        state.empty = !tasks.length;
      }

      if (state.empty && state.workflows) {
        // open the first form if the kanban is empty
        state.createTaskForm = state.workflows[0].statuses[0].slug;
      } else {
        state.createTaskForm = '';
      }

      return state;
    }
  ),
  on(
    KanbanApiActions.createTaskSuccess,
    (state, { task, tmpId }): KanbanState => {
      state.tasks[task.status] = state.tasks[task.status].map((it) => {
        if ('tmpId' in it) {
          return it.tmpId === tmpId ? task : it;
        }

        return it;
      });

      return state;
    }
  ),
  on(KanbanApiActions.createTaskError, (state, { task }): KanbanState => {
    if ('tmpId' in task) {
      state.tasks[task.status] = state.tasks[task.status].filter((it) => {
        return !('tmpId' in it && it.tmpId === task.tmpId);
      });
    }

    return state;
  }),
  on(KanbanActions.scrolledToNewTask, (state, { tmpId }): KanbanState => {
    state.scrollToTask = state.scrollToTask.filter((it) => it !== tmpId);

    return state;
  }),
  on(KanbanEventsActions.newTask, (state, { task }): KanbanState => {
    state.tasks[task.status].push(task);

    state.newEventTasks.push(task.reference);

    return state;
  }),
  on(
    KanbanActions.timeoutAnimationEventNewTask,
    (state, { reference }): KanbanState => {
      state.newEventTasks = state.newEventTasks.filter((it) => {
        return it !== reference;
      });

      return state;
    }
  )
);

export const kanbanFeature = createFeature({
  name: 'kanban',
  reducer: immerReducer(reducer),
});
