from app.database import SessionLocal, engine
from app.models.models import User


def redacted_url() -> str:
    url = engine.url
    try:
        return url.render_as_string(hide_password=True)
    except Exception:
        return str(url)


def main():
    print("Database URL:")
    print(redacted_url())
    print()

    db = SessionLocal()
    try:
        users = db.query(User).order_by(User.id).all()

        if not users:
            print("No users found.")
            return

        print("Users:")
        for user in users:
            print(f"{user.id}: {user.email} | {user.role} | {user.first_name} {user.last_name}")
    finally:
        db.close()


if __name__ == "__main__":
    main()