import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest
from aiocqhttp import Event
from aiocqhttp.exceptions import ApiNotAvailable

from astrbot.core.message.components import At
from astrbot.core.platform.sources.aiocqhttp.aiocqhttp_platform_adapter import (
    AiocqhttpAdapter,
)
from astrbot.core.platform.sources.aiocqhttp.client import ReconnectSafeCQHttp


def test_old_socket_close_preserves_replacement():
    old, new = object(), object()
    client = ReconnectSafeCQHttp.__new__(ReconnectSafeCQHttp)
    client._wsr_api_clients = {"123": new}
    socket = SimpleNamespace(
        headers={"X-Self-ID": "123"}, _get_current_object=lambda: old
    )
    with patch("astrbot.core.platform.sources.aiocqhttp.client.websocket", socket):
        client._remove_wsr_api_client()
    assert client._wsr_api_clients["123"] is new
    socket._get_current_object = lambda: new
    with patch("astrbot.core.platform.sources.aiocqhttp.client.websocket", socket):
        client._remove_wsr_api_client()
        client._remove_wsr_api_client()
    assert client._wsr_api_clients == {}


@pytest.mark.asyncio
@pytest.mark.parametrize("lookup", [None, ApiNotAvailable(), asyncio.TimeoutError()])
async def test_mentions_survive_missing_user_info(lookup):
    adapter = AiocqhttpAdapter.__new__(AiocqhttpAdapter)
    adapter.bot = SimpleNamespace(call_action=AsyncMock())
    if isinstance(lookup, Exception):
        adapter.bot.call_action.side_effect = lookup
    else:
        adapter.bot.call_action.return_value = lookup
    event = Event(
        {
            "post_type": "message",
            "message_type": "group",
            "self_id": 123,
            "user_id": 456,
            "group_id": 789,
            "message_id": 1,
            "sender": {"user_id": 456, "nickname": "user"},
            "message": [
                {"type": "at", "data": {"qq": "123"}},
                {"type": "at", "data": {"qq": "456"}},
                {"type": "text", "data": {"text": "hello"}},
            ],
        }
    )
    result = await adapter.convert_message(event)
    assert [str(x.qq) for x in result.message if isinstance(x, At)] == ["123", "456"]
    assert "hello" in result.message_str
    assert "(123)" not in result.message_str
    adapter.bot.call_action.assert_awaited_once()


@pytest.mark.asyncio
async def test_lookup_cancellation_is_not_swallowed():
    adapter = AiocqhttpAdapter.__new__(AiocqhttpAdapter)
    adapter.bot = SimpleNamespace(
        call_action=AsyncMock(side_effect=asyncio.CancelledError())
    )
    event = Event(
        {
            "post_type": "message",
            "message_type": "group",
            "self_id": 123,
            "user_id": 456,
            "group_id": 789,
            "message_id": 1,
            "sender": {"user_id": 456},
            "message": [{"type": "at", "data": {"qq": "456"}}],
        }
    )
    with pytest.raises(asyncio.CancelledError):
        await adapter.convert_message(event)
