from types import SimpleNamespace

import app.services.route_optimizer as route_optimizer


class DummyStudent(SimpleNamespace):
    pass


class FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self._payload


def test_optimize_route_with_osrm_returns_order_and_geometry(monkeypatch):
    students = [
        DummyStudent(id=1, latitude=31.24, longitude=34.79),
        DummyStudent(id=2, latitude=31.25, longitude=34.80),
    ]

    def fake_get(url):
        if "trip/v1/driving" in url:
            return FakeResponse({
                "waypoints": [
                    {"waypoint_index": 1},
                    {"waypoint_index": 0},
                ],
                "trips": [{}],
            })

        return FakeResponse({
            "routes": [
                {
                    "geometry": {
                        "type": "LineString",
                        "coordinates": [[34.79, 31.24], [34.80, 31.25]],
                    }
                }
            ]
        })

    monkeypatch.setattr(route_optimizer.requests, "get", fake_get)

    ordered_students, geometry = route_optimizer.optimize_route_with_osrm(students)

    assert [student.id for student in ordered_students] == [2, 1]
    assert geometry == [[34.79, 31.24], [34.80, 31.25]]
