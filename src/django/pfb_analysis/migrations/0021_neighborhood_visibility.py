# -*- coding: utf-8 -*-
# Generated by Django 1.10.3 on 2017-05-09 14:52
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('pfb_analysis', '0020_neighborhood_geom_simple'),
    ]

    operations = [
        migrations.AddField(
            model_name='neighborhood',
            name='visibility',
            field=models.CharField(choices=[('public', 'Public'), ('private', 'Private')], default='public', max_length=10),
        ),
    ]
