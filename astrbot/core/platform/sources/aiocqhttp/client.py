"""Reverse WebSocket client with connection-identity-safe cleanup."""

from aiocqhttp import CQHttp
from quart import websocket


class ReconnectSafeCQHttp(CQHttp):
    def _remove_wsr_api_client(self) -> None:
        """Remove only the closing socket, preserving any replacement connection."""
        ws = websocket._get_current_object()
        self_id = websocket.headers["X-Self-ID"]
        # An old socket can finish closing after its replacement is registered.
        if self._wsr_api_clients.get(self_id) is ws:
            del self._wsr_api_clients[self_id]
