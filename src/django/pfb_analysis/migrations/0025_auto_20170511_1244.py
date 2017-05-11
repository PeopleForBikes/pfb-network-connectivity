# -*- coding: utf-8 -*-
# Generated by Django 1.10.3 on 2017-05-11 12:44
from __future__ import unicode_literals

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('pfb_analysis', '0024_auto_20170509_2121'),
    ]

    operations = [
        migrations.AlterField(
            model_name='neighborhood',
            name='last_job',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='last_job_neighborhood', to='pfb_analysis.AnalysisJob'),
        ),
    ]