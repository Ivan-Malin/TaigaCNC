/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2023-present Kaleidos INC
 */

import { Validators } from '@angular/forms';

export const StoryTitleMaxLength = 500;

// export function notNullValidator(): ValidatorFn {
//   return (control: AbstractControl): { [key: string]: any } | null => {
//     const value = control.value;
//     return value !== null && value !== undefined && value !== '' ? null : { 'notNull': true };
//   };
// }

// export const StoryTitleValidation = [
//   Validators.required,
//   notNullValidator(),
//   Validators.maxLength(StoryTitleMaxLength),
//   Validators.pattern(/^(\s+\S+\s*)*(?!\s).*$/),
// ];
// export const StoryTitleCNC = [
//   Validators.required,
//   Validators.maxLength(StoryTitleMaxLength),
//   Validators.pattern(/^(\s+\S+\s*)*(?!\s).*$/),
// ];


export const StoryTitleValidation = [
  Validators.required,
  Validators.maxLength(StoryTitleMaxLength),
  Validators.pattern(/^(\s+\S+\s*)*(?!\s).*$/),
];
