from django.db import models
from django.contrib.auth.base_user import BaseUserManager
from django.contrib.auth.models import AbstractBaseUser

class UserManager(BaseUserManager):
    def create_user(self, email, phone_number, password=None):

        if not email:
            raise ValueError('Users must have an email address')
        if not password:
            raise ValueError('Users must have a password')
        if not phone_number:
            raise ValueError('Users must have a phone number')

        user = self.model(
            email=self.normalize_email(email),
            phone_number=phone_number,
        )

        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_staffuser(self, email, phone_number, password):

        user = self.create_user(
            email,
            phone_number,
            password=password
        )
        user.staff = True
        user.save(using=self._db)
        return user

    def create_superuser(self, email, phone_number, password):

        user = self.create_user(
            email,
            phone_number,
            password=password,
        )
        user.staff = True
        user.admin = True
        user.save(using=self._db)
        return user

class User(AbstractBaseUser):
    email = models.EmailField(
            verbose_name='email address',
            max_length=255,
            unique=True)
    phone_number = models.CharField(max_length=8,default='00000000',unique=True)
    active = models.BooleanField(default=True)
    staff = models.BooleanField(default=False)
    admin = models.BooleanField(default=False)
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['phone_number']

    objects = UserManager()

    def get_full_name(self):

        return self.email

    def get_short_name(self):

        return self.email
    
    def has_perm(self, perm, obj=None):

        return True

    def has_module_perms(self, app_label):

        return True

    def __str__(self):
        return self.email

    @property
    def is_staff(self):

        return self.staff

    @property
    def is_admin(self):

        return self.admin

    @property
    def is_active(self):
        return self.active



    


