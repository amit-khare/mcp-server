from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_env: str = "local"
    oauth_client_id: str
    oauth_client_secret: str
    cognito_region: str
    user_pool_id: str
    app_client_id: str
    token_url: str

    class Config:
        env_file = ".env"
        case_sensitive = False

settings = Settings()