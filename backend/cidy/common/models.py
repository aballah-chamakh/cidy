from django.db import models

# Create your models here.

class Level(models.Model):
    name = models.CharField(max_length=100, unique=True)

class Section(models.Model):
    name = models.CharField(max_length=100, unique=True)
    level = models.ForeignKey(Level, on_delete=models.CASCADE)

class Subject(models.Model):
    name = models.CharField(max_length=100, unique=True)
    level = models.ForeignKey(Level, on_delete=models.CASCADE,null=True, blank=True)
    section = models.ForeignKey(Section, on_delete=models.CASCADE,null=True, blank=True)
