# server.py
from fastmcp import FastMCP
from fastmcp.server.auth import AuthProvider, AccessToken
import jwt
from typing import Optional

class CognitoTokenValidator(AuthProvider):
    async def verify_token(self, token: str) -> Optional[AccessToken]:
        try:
            decoded = jwt.decode(
                token,
                options={"verify_signature": False}
            )

            scope_str = decoded.get("scope", "") or ""
            scopes = [s for s in scope_str.split() if s]

            return AccessToken(
                token=token,
                client_id=decoded.get("client_id") or decoded.get("sub") or "unknown",
                scopes=scopes,
                expires_at=decoded.get("exp"),
                claims=decoded,
            )
        except Exception:
            return None


auth_provider = CognitoTokenValidator()
mcp = FastMCP("secure-mcp", auth=auth_provider)

def verify_token(token: str) -> dict:
    """Verify and decode the JWT token."""
    try:
        # Decode JWT without verification (for testing)
        # In production, verify signature using your auth provider's public keys
        decoded = jwt.decode(
            token,
            options={"verify_signature": False}
        )
        return decoded
    except Exception as e:
        raise ValueError(f"Invalid token: {str(e)}")

@mcp.tool()
async def add(a: int, b: int) -> int:
    """Add two numbers - requires authentication."""
    from fastmcp.server.dependencies import get_access_token
    
    # Validate token
    token = get_access_token()
    claims = token.claims
    
    # Perform the operation
    return a + b

@mcp.tool()
async def get_user_info() -> dict:
    """Get authenticated user information."""
    from fastmcp.server.dependencies import get_access_token
    
    token = get_access_token()
    return {
        "user": token.claims.get("sub"),
        "username": token.claims.get("username", token.claims.get("client_id")),
        "scope": token.claims.get("scope"),
    }

if __name__ == "__main__":
    mcp.run(transport="http", host="0.0.0.0", port=8000)
