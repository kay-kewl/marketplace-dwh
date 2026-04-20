import os

SQLALCHEMY_DATABASE_URI = "postgresql+psycopg2://superset:superset@superset-db:5432/superset"
SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY", "change_me_superset_secret_key")
WTF_CSRF_ENABLED = True