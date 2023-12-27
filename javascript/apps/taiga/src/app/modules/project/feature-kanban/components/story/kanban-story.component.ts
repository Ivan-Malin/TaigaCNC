/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2023-present Kaleidos INC
 */

import { Location, SlicePipe, CommonModule } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  HostBinding,
  Input,
  OnChanges,
  OnInit,
  SimpleChanges,
  forwardRef,
} from '@angular/core';
import { UntilDestroy } from '@ngneat/until-destroy';
import { Store } from '@ngrx/store';
import { RxState } from '@rx-angular/state';
import { Membership, Project, Story, User } from '@taiga/data';
import { distinctUntilChanged, map } from 'rxjs';
import { selectUser } from '~/app/modules/auth/data-access/+state/selectors/auth.selectors';
import { selectCurrentProject } from '~/app/modules/project/data-access/+state/selectors/project.selectors';
import { KanbanActions } from '~/app/modules/project/feature-kanban/data-access/+state/actions/kanban.actions';
import { selectActiveA11yDragDropStory } from '~/app/modules/project/feature-kanban/data-access/+state/selectors/kanban.selectors';
import { KanbanStory } from '~/app/modules/project/feature-kanban/kanban.model';
import { PermissionsService } from '~/app/services/permissions.service';
import { filterNil } from '~/app/shared/utils/operators';
import { KanbanStatusComponent } from '../status/kanban-status.component';
import { TuiDropdownModule } from '@taiga-ui/core/directives/dropdown';

import { TuiSvgModule } from '@taiga-ui/core';
import { RouterLink } from '@angular/router';
import { TranslocoDirective } from '@ngneat/transloco';
import { TooltipDirective } from '@taiga/ui/tooltip';
import { HasPermissionDirective } from '~/app/shared/directives/has-permissions/has-permission.directive';
import { OutsideClickDirective } from '~/app/shared/directives/outside-click/outside-click.directive';
import { UserAvatarComponent } from '~/app/shared/user-avatar/user-avatar.component';
import { AssignUserComponent } from '~/app/modules/project/components/assign-user/assign-user.component';
import { Observable } from 'rxjs';
import { HttpClient, HttpClientModule } from '@angular/common/http';


export interface StoryState {
  isA11yDragInProgress: boolean;
  project: Project;
  showAssignUser: boolean;
  assignees: Story['assignees'];
  currentUser: User;
  canEdit: boolean;
}

// model$ is forwardly reffering to this.state dict. If we want to bypass variables, we can use vm (i.e. this.state)
@UntilDestroy()
@Component({
  selector: 'tg-kanban-story',
  templateUrl: './kanban-story.component.html',
  styleUrls: ['./kanban-story.component.css'],
  providers: [RxState],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: true,
  imports: [
    CommonModule,
    TranslocoDirective,
    RouterLink,
    TuiSvgModule,
    HasPermissionDirective,
    TuiDropdownModule,
    TooltipDirective,
    UserAvatarComponent,
    AssignUserComponent,
    OutsideClickDirective,
    SlicePipe,
    HttpClientModule,
    forwardRef(() => KanbanStatusComponent),
  ],
})
export class KanbanStoryComponent implements OnChanges, OnInit {
  @Input()
  public story!: KanbanStory;

  @Input()
  @HostBinding('attr.data-position')
  public index!: number;

  @Input()
  public total = 0;

  @Input()
  public kanbanStatus?: KanbanStatusComponent;


  @Input()
  public progressData: any;

  @HostBinding('attr.data-test')
  public dataTest = 'kanban-story';

  @HostBinding('class.drag-shadow')
  public get dragShadow() {
    return this.story._shadow || this.story._dragging;
  }

  @HostBinding('attr.data-ref')
  public get ref() {
    return this.story.ref;
  }

  public assignedListA11y = '';
  public reversedAssignees: Membership['user'][] = [];
  public restAssigneesLenght = '';
  public cardHasFocus = false;

  public readonly model$ = this.state.select();

  public get nativeElement() {
    return this.el.nativeElement as HTMLElement;
  }

  constructor(
    public state: RxState<StoryState>,
    private location: Location,
    private store: Store,
    private el: ElementRef,
    private permissionService: PermissionsService,
    private http: HttpClient
  ) {
    this.state.set({
      assignees: [],
      showAssignUser: false,
    });
  }

  public ngOnInit(): void {
    this.state.connect(
      'isA11yDragInProgress',
      this.store.select(selectActiveA11yDragDropStory).pipe(
        map((it: { ref: any; }) => it.ref === this.story.ref),
        distinctUntilChanged()
      )
    );
    this.state.connect(
      'project',
      this.store.select(selectCurrentProject).pipe(filterNil())
    );
    this.state.connect(
      'currentUser',
      this.store.select(selectUser).pipe(filterNil())
    );
    this.state.connect(
      'canEdit',
      this.permissionService.hasPermissions$('story', ['modify'])
    );
    // this.state.connect(
    //   'isCNC',
    //   this.permissionService.hasPermissions$('story', ['modify'])
    // );

    this.state.hold(this.state.select('currentUser'), () => {
      this.setAssigneesInState();
      this.setAssignedListA11y();
      this.calculateRestAssignes();
    });
    // Implement ngOnInit logic here
    window.onload = () => {
      let titleCNC = `{
        "files":
        [
         {
          "file_name":"A",
          "estimated_time":"1"
         },
         {
          "file_name":"B",
          "estimated_time":"1"
         },
         {
          "file_name":"C",
          "estimated_time":"1"
         },
         {
          "file_name":"D",
          "estimated_time":"1"
         },
        {
          "file_name":"E",
          "estimated_time":"1"
         }
        ],
        "progress":
        {
          "remaining_all_time":1000,
          "current_file_time":100,
          "current_completed_file_time":90,
          "state":"resumed"
        }
      }`;
    
      let data = JSON.parse(titleCNC);
    
      let table = document.querySelector('table.tasks_cnc tbody') as HTMLTableElement | null;
      let remainingTime = document.getElementById('remainingTime');
      let currentTaskName = document.getElementById('currentTaskName');
      let progressText = document.getElementById('progressText');
      let progressBar = document.querySelector('.progress') as HTMLElement | null;
    
      if (remainingTime && currentTaskName && progressText && progressBar && table) {
        remainingTime.textContent = "Текущие задачи: " + data.progress.remaining_all_time;
        currentTaskName.textContent = data.files[0]?.file_name;
    
        // Calculate the progress percentage
        let progressPercentage = ((data.progress.current_completed_file_time ?? 0) / (data.progress.current_file_time ?? 1)) * 100;
        progressText.textContent = `${data.progress.current_completed_file_time ?? 0} / ${data.progress.current_file_time ?? 1}`;
        if (progressBar) {
          progressBar.style.width = `${progressPercentage}%`;
        }
    
        // Add rows to the table equal to the length of files
        while (table.rows.length < data.files.length) {
            table.insertRow();
        }
    
        // Update the cells with file_name and estimated_time
        data.files.forEach((item: { file_name: string; estimated_time: string; }, index: number) => {
            if (table) {
              let tr: HTMLTableRowElement = table.rows[index];
              let td1 = tr.cells[0] || tr.insertCell(0);
              let td2 = tr.cells[1] || tr.insertCell(1);
              td1.innerText = item.file_name;
              td2.innerText = item.estimated_time;
            }
        });
      }
    };
  }

  public ngOnChanges(changes: SimpleChanges): void {
    if (changes.story && this.story._shadow) {
      requestAnimationFrame(() => {
        this.scrollToDragStoryIfNotVisible();
      });
    }
    // var updatedStory = changes.story.currentValue as KanbanStory; // Type assertion to KanbanStory
    //   if (updatedStory.titleCNC) {
    //     // (KanbanStory) changes.story
    //     // this.progressData = JSON.parse(changes.story.titleCNC.currentValue);
    //     this.progressData = JSON.parse(updatedStory.titleCNC);
    //   }


    if (changes.story && this.state.get('currentUser')) {
      this.setAssigneesInState();
      this.setAssignedListA11y();
      this.calculateRestAssignes();
    }
  }

  public setAssigneesInState() {
    const assignees: Membership['user'][] = [];

    const currentUserMember = this.story.assignees.find((member: { username: any; }) => {
      return member.username === this.state.get('currentUser').username;
    });

    const members = this.story.assignees.filter((member: { username: any; }) => {
      if (member.username === this.state.get('currentUser').username) {
        return false;
      }

      return true;
    });

    if (currentUserMember) {
      assignees.push(currentUserMember);
    }
    members.forEach((member: Pick<User, "username" | "fullName" | "color">) => assignees.push(member));
    // Required for styling reasons (inverted flex)
    this.reversedAssignees = [...assignees].reverse();

    this.state.set({ assignees });
  }

  public setAssignedListA11y() {
    this.assignedListA11y = this.state
      .get('assignees')
      .map((assigned: { fullName: any; }) => assigned.fullName)
      .join(', ');
  }

  public handleCardFocus(value: boolean) {
    this.cardHasFocus = value;
  }

  public openStory(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();

    if (this.story.ref) {
      this.location.go(
        `project/${this.state.get('project').id}/${
          this.state.get('project').slug
        }/stories/${this.story.ref}`,
        undefined,
        {
          fromCard: true,
        }
      );
    }
  }

  public toggleAssignUser(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();

    this.state.set('showAssignUser', ({ showAssignUser }) => {
      return !showAssignUser;
    });
  }

  public assign(member: Membership['user']) {
    if (this.story.ref) {
      this.store.dispatch(
        KanbanActions.assignMember({ member, storyRef: this.story.ref })
      );
    }
  }

  public unassign(member: Membership['user']) {
    if (this.story.ref) {
      this.store.dispatch(
        KanbanActions.unAssignMember({ member, storyRef: this.story.ref })
      );
    }
  }

  public closeAssignDropdown() {
    this.state.set({ showAssignUser: false });
  }

  public trackByIndex(index: number) {
    return index;
  }

  public calculateRestAssignes() {
    const restAssigneesLenght = this.state.get('assignees').length - 3;
    if (restAssigneesLenght < 99) {
      this.restAssigneesLenght = `${restAssigneesLenght}+`;
    } else {
      this.restAssigneesLenght = '…';
    }
  }

  private scrollToDragStoryIfNotVisible() {
    const kanbanStatus = this.kanbanStatus;

    if (!kanbanStatus) {
      return;
    }

    const statusScrollBottom =
      kanbanStatus.kanbanVirtualScroll?.scrollStrategy.viewport?.elementRef.nativeElement.getBoundingClientRect()
        .bottom;
    if (statusScrollBottom) {
      const newTop =
        this.nativeElement.getBoundingClientRect().bottom -
        statusScrollBottom +
        1;
      if (newTop > 0) {
        kanbanStatus.kanbanVirtualScroll?.scrollStrategy.scrollTo({
          top: newTop,
        });
      }
    }
  }



  public handlePause(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();
    this.http.get(`api/v2/projects/${this.state.get('project').id}/stories/${this.story.ref}/control/pause`).subscribe(
      {next:(data:any) => console.log(data)}
    );
  }
  public handleKill(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();

    // Working perfectly
    this.http.get(`api/v2/projects/${this.state.get('project').id}/stories/${this.story.ref}/control/kill`).subscribe(
      {next:(data:any) => console.log(data)}
    );
  }
  public handleResume(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();

    this.http.get(`api/v2/projects/${this.state.get('project').id}/stories/${this.story.ref}/control/resume`).subscribe(
      {next:(data:any) => console.log(data)}
    );
  }

  @Input()
  public file: string | ArrayBuffer | null = "";
  @Input()
  public file_name = "";
  @Input()
  public estimated_time = 0;
  // @Input()
  // public is_CNC = false;


  // files methods (events)
  public onFileSelected(event: any) {
    const selectedFile = event.target.files[0];
    if (selectedFile) {
      this.file_name = selectedFile.name;
      const reader = new FileReader();
      reader.readAsDataURL(selectedFile);
      reader.onload = () => {
          console.log("Selected file:", reader.result);
          this.file = reader.result;
      };
      // Do something with the selected file, such as uploading it to a server or processing it
      console.log('Selected file_name:', selectedFile.name);
    }
  }


  public post_task(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();

    var body = {file_name: this.file_name, estimated_time: this.estimated_time, file: this.file};

    this.http.post(`api/v2/projects/${this.state.get('project').id}/stories/${this.story.ref}/${this.story.version}/post_task`, body).subscribe(
      {next:(data:any) => console.log(data)}
    );
  }
  // calculateProgressWidth(): number {
  //   const remainingTime = this.progressData.progress.remaining_all_time;
  //   const completedTime = this.getTotalCompletedTime();
  //   console.log(`${((completedTime / remainingTime) * 100)} width progress bars`);
  //   return ((completedTime / remainingTime) * 100);
  // }

  // getTotalCompletedTime(): number {
  //   return this.progressData.files.reduce((total: number, estimated_time : string) => total + parseInt(estimated_time), 0);
  // }

}
