/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  EventEmitter,
  HostListener,
  Input,
  OnChanges,
  OnInit,
  Output,
  SimpleChanges,
  ViewChild,
} from '@angular/core';
import { FormArray, FormBuilder, FormGroup } from '@angular/forms';
import { Store } from '@ngrx/store';
import {
  Membership,
  Invitation,
  InvitationRequest,
  Project,
  Role,
  User,
  Contact,
} from '@taiga/data';
import { initRolesPermissions } from '~/app/modules/project/settings/feature-roles-permissions/+state/actions/roles-permissions.actions';
import {
  inviteUsersSuccess,
  addSuggestedContact,
  searchUser,
} from '~/app/shared/invite-to-project/data-access/+state/actions/invitation.action';
import {
  selectContacts,
  selectMemberRolesOrdered,
  selectSuggestedUsers,
  selectUsersToInvite,
} from '~/app/shared/invite-to-project/data-access/+state/selectors/invitation.selectors';
import { selectUser } from '~/app/modules/auth/data-access/+state/selectors/auth.selectors';
import { BehaviorSubject, Observable, Subject } from 'rxjs';
import {
  map,
  share,
  startWith,
  switchMap,
  throttleTime,
} from 'rxjs/operators';
import { TRANSLOCO_SCOPE } from '@ngneat/transloco';
import { inviteUsersToProject } from '~/app/modules/feature-new-project/+state/actions/new-project.actions';
import { Actions, concatLatestFrom, ofType } from '@ngrx/effects';
import { UntilDestroy, untilDestroyed } from '@ngneat/until-destroy';
import { TuiTextAreaComponent } from '@taiga-ui/kit';
import { TuiScrollbarComponent } from '@taiga-ui/core';
import { InvitationService } from '~/app/services/invitation.service';

interface InvitationForm {
  fullName: string;
  username?: string;
  roles: string;
  email?: string;
}
@UntilDestroy()
@Component({
  selector: 'tg-invite-to-project',
  templateUrl: './invite-to-project.component.html',
  styleUrls: [
    './styles/invite-to-project.shared.css',
    './invite-to-project.component.css',
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    {
      provide: TRANSLOCO_SCOPE,
      useValue: {
        scope: 'invitation_modal',
        alias: 'invitation_modal',
      },
    },
  ],
})
export class InviteToProjectComponent implements OnInit, OnChanges {
  @ViewChild(TuiScrollbarComponent, { read: ElementRef })
  private readonly scrollBar?: ElementRef<HTMLElement>;

  @Input()
  public project!: Project;

  @Input()
  public pending?: Invitation[];

  @Input()
  public reset?: boolean;

  @Input()
  public members?: (Membership | Invitation)[];

  @Output()
  public closeModal = new EventEmitter();

  @ViewChild('emailInput', { static: false })
  public emailInput!: TuiTextAreaComponent;

  @ViewChild('textArea')
  private textArea!: ElementRef<HTMLElement>;

  @HostListener('window:beforeunload')
  public unloadHandler() {
    return !this.formHasContent();
  }

  public regexpEmail = /\w+([.\-_+]?\w+)*@\w+([.-]?\w+)*(\.\w{2,4})+/g;
  public inviteIdentifier = '';
  public inviteIdentifier$ = new BehaviorSubject('');
  public inviteIdentifierErrors: {
    required: boolean;
    regex: boolean;
    listEmpty: boolean;
    peopleNotAdded: boolean;
    bulkError: boolean;
    moreThanFifty: boolean;
  } = {
    required: false,
    regex: false,
    listEmpty: false,
    peopleNotAdded: false,
    bulkError: false,
    moreThanFifty: false,
  };
  public inviteProjectForm: FormGroup = this.fb.group({
    users: new FormArray([]),
  });
  public orderedRoles!: Role[] | null;

  public validEmails$ = new BehaviorSubject([] as string[]);
  public memberRoles$ = this.store.select(selectMemberRolesOrdered);
  public contacts$ = this.store.select(selectContacts);
  public suggestedUsers$ = this.store.select(selectSuggestedUsers);
  public usersToInvite$!: Observable<Partial<User>[]>;
  public validInviteIdentifier$!: Observable<RegExpMatchArray>;
  public emailsWithoutDuplications$!: Observable<string[]>;
  public suggestedUsers: Contact[] = [];
  public suggestionSelected = 0;
  public elegibleSuggestions: number[] | undefined = [];
  public search$: Subject<string | null> = new Subject();
  public notInBulkMode = true;

  constructor(
    private fb: FormBuilder,
    private store: Store,
    private actions$: Actions,
    private invitationService: InvitationService
  ) {
    this.actions$
      .pipe(ofType(inviteUsersSuccess), untilDestroyed(this))
      .subscribe(() => {
        this.close();
      });

    this.validInviteIdentifier$ = this.inviteIdentifier$.pipe(
      throttleTime(200, undefined, { leading: true, trailing: true }),
      map((emails) => this.validateEmails(emails)),
      share(),
      startWith([])
    );

    this.emailsWithoutDuplications$ = this.validInviteIdentifier$.pipe(
      map((emails) =>
        emails?.filter((email, i) => emails.indexOf(email) === i)
      ),
      share(),
      startWith([])
    );
  }

  public get users() {
    return (this.inviteProjectForm.controls['users'] as FormArray)
      .controls as FormGroup[];
  }

  public get emailsHaveErrors() {
    return (
      this.inviteIdentifierErrors.required ||
      this.inviteIdentifierErrors.regex ||
      this.inviteIdentifierErrors.peopleNotAdded ||
      this.inviteIdentifierErrors.bulkError
    );
  }

  public get suggestionContactsDropdownActivate() {
    return (
      !!(this.inviteIdentifier.length > 1) &&
      !!this.suggestedUsers.length &&
      !!this.notInBulkMode
    );
  }

  public get parseTextToHighlight() {
    return this.inviteIdentifier.replace(/^@/, '');
  }

  public ngOnInit() {
    this.usersToInvite$ = this.validEmails$.pipe(
      switchMap((validEmails) => {
        return this.store.select(selectUsersToInvite(validEmails));
      })
    );

    this.store.dispatch(initRolesPermissions({ project: this.project }));

    // when we add users to invite its necessary to add the result to the form
    this.usersToInvite$
      .pipe(concatLatestFrom(() => this.store.select(selectUser)))
      .subscribe(([userToInvite, currentUser]) => {
        userToInvite.forEach((user) => {
          const userAlreadyExist = this.users?.find((it: FormGroup) => {
            return (it.value as Partial<User>).email
              ? (it.value as Partial<User>).email === user.email
              : (it.value as Partial<User>).username === user.username;
          });
          const isCurrentUser = currentUser?.email
            ? currentUser?.email === user.email
            : currentUser?.username === user.username;
          const isAlreadyProjectMember =
            !!user.username &&
            this.members
              ?.filter((it) => !(it as Invitation).email)
              ?.find((member) => member.user?.username === user.username);
          if (!userAlreadyExist && !isCurrentUser && !isAlreadyProjectMember) {
            this.users.splice(
              this.positionInArray(user),
              0,
              this.fb.group(user)
            );
          }
        });
        this.resetField();
        this.emailInput?.nativeFocusableElement?.focus();
      });

    this.memberRoles$.subscribe((memberRoles) => {
      this.orderedRoles = memberRoles;
    });

    this.suggestedUsers$.subscribe((suggestedUsers) => {
      this.suggestedUsers = suggestedUsers;
      this.elegibleSuggestions = [];
      this.suggestedUsers.forEach((it, i) => {
        if (!it.isMember) {
          this.elegibleSuggestions?.push(i);
        }
      });
      this.suggestionSelected = this.elegibleSuggestions?.[0] || 0;
    });
  }

  public ngOnChanges(changes: SimpleChanges) {
    changes.reset && this.cleanFormBeforeClose();
  }

  public positionInArray(user: Partial<User>) {
    const tempInvitations = this.users.map((it) => {
      const data = it.value as InvitationForm;
      return {
        user:
          data.username && data.fullName
            ? { username: data.username, fullName: data.fullName }
            : undefined,
        email: data.email || '',
        role: {
          isAdmin: data.roles === 'Administrator',
          name: data.roles,
        },
      };
    });
    const tempInvitation = {
      user:
        user.username && user.fullName
          ? { username: user.username, fullName: user.fullName }
          : undefined,
      email: user.email || '',
      role: {
        isAdmin: (user.roles && user.roles[0]) === 'Administrator',
        name: user.roles && user.roles[0],
      },
    };
    return this.invitationService.positionInvitationInArray(
      tempInvitations,
      tempInvitation
    );
  }

  public validateEmails(emails: string) {
    return emails.match(this.regexpEmail) || [];
  }

  public formHasContent() {
    return !!this.inviteIdentifier || !!this.users.length;
  }

  public trackByIndex(index: number) {
    return index;
  }

  public isPending(username: string) {
    return !!this.pending?.find((it) => it.user?.username === username);
  }

  public searchChange(emails: string) {
    (!emails || this.emailsHaveErrors) && this.resetErrors();
    this.suggestionSelected = this.elegibleSuggestions?.[0] || 0;
    if (/[^@]+@/.test(emails)) {
      // when the input contains and @ the search is disabled
      this.notInBulkMode = false;
      this.inviteIdentifier$.next(emails);
      this.handleAccessibilityAttributes(false);
    } else if (emails.trim().length > 1) {
      this.notInBulkMode = true;
      const searchText = this.inviteIdentifier.replace(/^@/, '');
      this.store.dispatch(
        searchUser({
          searchUser: {
            text: searchText,
            project: this.project.slug,
          },
        })
      );
      this.handleAccessibilityAttributes(true);
    }
  }

  public onSearchChange(searchQuery: string | null): void {
    this.search$.next(searchQuery);
  }

  public extractValueFromEvent(event: Event): string | null {
    return (event.target as HTMLInputElement)?.value || null;
  }

  public resetErrors() {
    this.inviteIdentifierErrors = {
      required: false,
      regex: false,
      listEmpty: false,
      peopleNotAdded: false,
      bulkError: false,
      moreThanFifty: false,
    };
  }

  public filterValidEmails(value: string) {
    return value.match(this.regexpEmail) || [];
  }

  public addUser() {
    const emailRgx = this.regexpEmail.test(this.inviteIdentifier);
    const bulkErrors = this.inviteIdentifier
      .replace(this.regexpEmail, '')
      .replace(/[;,\s\n]/g, '');

    this.resetErrors();
    if (this.suggestionContactsDropdownActivate) {
      this.includeSuggestedContact(this.suggestionSelected);
    } else if (this.inviteIdentifier === '') {
      this.inviteIdentifierErrors.required = true;
    } else if (!emailRgx) {
      this.inviteIdentifierErrors.regex = true;
      this.notInBulkMode = false;
    } else if (bulkErrors) {
      this.inviteIdentifierErrors.bulkError = true;
    } else {
      this.validEmails$.next(this.filterValidEmails(this.inviteIdentifier));
    }
  }

  public deleteUser(i: number) {
    (this.inviteProjectForm.controls['users'] as FormArray).removeAt(i);
    // force recalculate scroll height in Firefox
    requestAnimationFrame(() => {
      if (this.scrollBar) {
        this.scrollBar.nativeElement.scrollTop = 0;
        this.scrollBar.nativeElement.scrollTop =
          this.scrollBar.nativeElement.scrollHeight;
      }
    });
  }

  public includeSuggestedContact(index: number, event?: Event) {
    event?.preventDefault();
    this.validEmails$.next([this.suggestedUsers[index].username]);
    this.store.dispatch(
      addSuggestedContact({ contact: this.suggestedUsers[index] })
    );
  }

  public handleArrow(arrow: 'up' | 'down') {
    const currentIndex =
      this.elegibleSuggestions?.findIndex(
        (it) => it === this.suggestionSelected
      ) || 0;
    if (this.elegibleSuggestions) {
      if (arrow === 'up') {
        const index = currentIndex === 0 ? currentIndex : currentIndex - 1;
        this.suggestionSelected = this.elegibleSuggestions[index];
      } else {
        const index =
          currentIndex === this.elegibleSuggestions.length - 1
            ? currentIndex
            : currentIndex + 1;
        this.suggestionSelected = this.elegibleSuggestions[index];
      }
    }
    this.updateActiveDescendant();
  }

  public handleAccessibilityAttributes(activate: boolean) {
    const textArea = this.textArea.nativeElement.querySelector('textarea');
    if (activate) {
      textArea?.setAttribute('role', 'combobox');
      textArea?.setAttribute('aria-controls', 'suggestions');
      textArea?.setAttribute('aria-autocomplete', 'list');
      textArea?.setAttribute('aria-haspopup', 'true');
      textArea?.setAttribute('aria-expanded', 'true');
    } else {
      textArea?.setAttribute('role', 'textbox');
      textArea?.setAttribute('aria-controls', '');
      textArea?.setAttribute('aria-autocomplete', '');
      textArea?.setAttribute('aria-haspopup', 'false');
      textArea?.setAttribute('aria-expanded', 'false');
      textArea?.setAttribute('aria-activedescendant', '');
      this.suggestionSelected = 0;
    }
    this.updateActiveDescendant();
  }

  public updateActiveDescendant() {
    const textArea = this.textArea.nativeElement.querySelector('textarea');
    textArea?.setAttribute(
      'aria-activedescendant',
      `suggestion-${this.suggestionSelected}`
    );
  }

  public getRoleSlug(roleName: string) {
    return this.orderedRoles?.find((role) => role.name === roleName);
  }

  public generatePayload(): InvitationRequest[] {
    return this.users.map((user) => {
      return {
        email: user.get('email')?.value as string,
        username: user.get('username')?.value as string,
        roleSlug:
          this.getRoleSlug(user.get('roles')?.value as string)?.slug || '',
      };
    });
  }

  public sendForm() {
    this.resetErrors();
    if (this.users.length > 50) {
      this.inviteIdentifierErrors.moreThanFifty = true;
    } else if (this.users.length && this.inviteIdentifier === '') {
      this.store.dispatch(
        inviteUsersToProject({
          slug: this.project.slug,
          invitation: this.generatePayload(),
        })
      );
    } else if (this.inviteIdentifier === '') {
      this.inviteIdentifierErrors.listEmpty = true;
      this.emailInput?.nativeFocusableElement?.focus();
    }
    this.inviteIdentifierErrors.peopleNotAdded = !!this.inviteIdentifier;
  }

  public cleanFormBeforeClose() {
    this.resetErrors();
    this.resetField();
    this.inviteProjectForm = this.fb.group({
      users: new FormArray([]),
    });
  }

  public resetField() {
    this.inviteIdentifier = '';
    this.searchChange('');
    this.inviteIdentifier$.next('');
  }

  public close() {
    this.cleanFormBeforeClose();
    this.closeModal.next();
  }
}
