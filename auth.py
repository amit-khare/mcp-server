# auth.py
import os
import httpx
from jose import jwt
from functools import lru_cache
from dotenv import load_dotenv
from config import settings
load_dotenv()



COGNITO_REGION = settings.cognito_region
USER_POOL_ID = settings.user_pool_id
APP_CLIENT_ID = settings.app_client_id

JWKS_URL = (
    f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/"
    f"{USER_POOL_ID}/.well-known/jwks.json"
)

@lru_cache
def get_jwks():
    return httpx.get(JWKS_URL).json()

def verify_token(token: str):
    jwks = get_jwks()
    header = jwt.get_unverified_header(token)

    key = next(
        k for k in jwks["keys"] if k["kid"] == header["kid"]
    )

    claims = jwt.decode(
        token,
        key,
        algorithms=["RS256"],
        audience=APP_CLIENT_ID,
        issuer=f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{USER_POOL_ID}",
    )

    return claims
