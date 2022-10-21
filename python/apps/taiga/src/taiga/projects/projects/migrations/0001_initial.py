# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

# Generated by Django 4.1.1 on 2022-09-30 08:09

import functools

import django.contrib.postgres.fields
import django.contrib.postgres.fields.jsonb
import taiga.base.db.models
import taiga.base.db.models.fields
import taiga.base.utils.files
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="Project",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        blank=True,
                        default=taiga.base.db.models.uuid_generator,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("name", models.CharField(max_length=80, verbose_name="name")),
                (
                    "slug",
                    taiga.base.db.models.fields.LowerSlugField(
                        blank=True, max_length=250, unique=True, verbose_name="slug"
                    ),
                ),
                ("description", models.CharField(blank=True, max_length=220, null=True, verbose_name="description")),
                ("color", models.IntegerField(blank=True, default=1, verbose_name="color")),
                (
                    "logo",
                    models.FileField(
                        blank=True,
                        max_length=500,
                        null=True,
                        upload_to=functools.partial(
                            taiga.base.utils.files.get_file_path, *(), **{"base_path": "project"}
                        ),
                        verbose_name="logo",
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="created at")),
                ("modified_at", models.DateTimeField(auto_now=True, verbose_name="modified at")),
                (
                    "public_permissions",
                    django.contrib.postgres.fields.ArrayField(
                        base_field=models.TextField(
                            choices=[
                                ("add_story", "Add story"),
                                ("comment_story", "Comment story"),
                                ("delete_story", "Delete story"),
                                ("modify_story", "Modify story"),
                                ("view_story", "View story"),
                                ("add_task", "Add task"),
                                ("comment_task", "Comment task"),
                                ("delete_task", "Delete task"),
                                ("modify_task", "Modify task"),
                                ("view_task", "View task"),
                            ]
                        ),
                        blank=True,
                        default=list,
                        null=True,
                        size=None,
                        verbose_name="public permissions",
                    ),
                ),
                (
                    "workspace_member_permissions",
                    django.contrib.postgres.fields.ArrayField(
                        base_field=models.TextField(
                            choices=[
                                ("add_story", "Add story"),
                                ("comment_story", "Comment story"),
                                ("delete_story", "Delete story"),
                                ("modify_story", "Modify story"),
                                ("view_story", "View story"),
                                ("add_task", "Add task"),
                                ("comment_task", "Comment task"),
                                ("delete_task", "Delete task"),
                                ("modify_task", "Modify task"),
                                ("view_task", "View task"),
                            ]
                        ),
                        blank=True,
                        default=list,
                        null=True,
                        size=None,
                        verbose_name="workspace member permissions",
                    ),
                ),
            ],
            options={
                "verbose_name": "project",
                "verbose_name_plural": "projects",
                "ordering": ["workspace", "slug"],
            },
        ),
        migrations.CreateModel(
            name="ProjectTemplate",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        blank=True,
                        default=taiga.base.db.models.uuid_generator,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("name", models.CharField(max_length=250, verbose_name="name")),
                (
                    "slug",
                    taiga.base.db.models.fields.LowerSlugField(
                        blank=True, max_length=250, unique=True, verbose_name="slug"
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="created at")),
                ("modified_at", models.DateTimeField(auto_now=True, verbose_name="modified at")),
                ("default_owner_role", models.CharField(max_length=50, verbose_name="default owner's role")),
                ("roles", django.contrib.postgres.fields.jsonb.JSONField(blank=True, null=True, verbose_name="roles")),
                (
                    "workflows",
                    django.contrib.postgres.fields.jsonb.JSONField(blank=True, null=True, verbose_name="workflows"),
                ),
            ],
            options={
                "verbose_name": "project template",
                "verbose_name_plural": "project templates",
                "ordering": ["name"],
            },
        ),
    ]