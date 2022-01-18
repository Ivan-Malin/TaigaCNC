# Generated by Django 2.2.24 on 2021-12-28 06:36

import django.contrib.postgres.fields
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('projects', '0070_project_color'),
    ]

    operations = [
        migrations.AlterField(
            model_name='project',
            name='anon_permissions',
            field=django.contrib.postgres.fields.ArrayField(base_field=models.TextField(), blank=True, default=list, null=True, size=None, verbose_name='anonymous permissions'),
        ),
        migrations.AlterField(
            model_name='project',
            name='public_permissions',
            field=django.contrib.postgres.fields.ArrayField(base_field=models.TextField(choices=[('view_project', 'View project'), ('view_us', 'View user story'), ('view_tasks', 'View tasks')]), blank=True, default=list, null=True, size=None, verbose_name='user permissions'),
        ),
    ]