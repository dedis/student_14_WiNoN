from __future__ import print_function

import argparse
import email
import imaplib2
import Queue
import select
import smtplib
import socket
import sys
import threading
import time

from email.mime import application, multipart, text


LOCAL_PORT = 18080
FLUSH_TIMEOUT = 1.

LOCAL_EMAIL = "winon.sweet.entry@gmail.com"
OTHER_EMAIL = "winon.sweet.exit@gmail.com"
EMAIL_USERNAME = "winon.sweet.entry@gmail.com"
EMAIL_PASSWORD = "lHzipJKORFqt"
IMAP_SERVER = "imap.gmail.com"
IMAP_PORT = 993
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 465


class Mailer(threading.Thread):

    def __init__(self):
        super(Mailer, self).__init__()
        self.smtp = smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT)
        self.smtp.login(EMAIL_USERNAME, EMAIL_PASSWORD)
        self.queue = Queue.Queue()
        self.quit = False

    def run(self):
        while True:
            if self.quit:
                self.smtp.quit()
                return
            time.sleep(FLUSH_TIMEOUT)
            buf = []
            while True:
                try:
                    buf.append(self.queue.get_nowait())
                except Queue.Empty:
                    break
            if not buf:
                continue
            data = b''.join(buf)
            msg = multipart.MIMEMultipart()
            msg["From"] = "Harry Truman <{}>".format(LOCAL_EMAIL)
            msg["To"] = "George Mason <{}>".format(OTHER_EMAIL)
            msg["Subject"] = "Important data"
            msg.attach(text.MIMEText("This isn't the real message."))
            attachment = application.MIMEApplication(data)
            msg.attach(attachment)
            self.smtp.sendmail(LOCAL_EMAIL, [OTHER_EMAIL], msg.as_string())


class MailChecker(threading.Thread):

    def __init__(self, outgoing):
        super(MailChecker, self).__init__()
        self.imap = imaplib2.IMAP4_SSL(IMAP_SERVER, IMAP_PORT)
        self.imap.login(EMAIL_USERNAME, EMAIL_PASSWORD)
        self.imap.select()
        self.outgoing = outgoing
        self.quit = False
        self.event = threading.Event()

    def stop(self):
        self.quit = True
        self.event.set()

    def run(self):
        def callback(args):
            if not self.event.set():
                self.event.set()
        while True:
            if self.quit:
                self.imap.expunge()
                self.imap.logout()
                return
            self.imap.idle(callback=callback)
            self.event.wait()
            self.check()

    def check(self):
        buf = []
        search = self.imap.search(None, "FROM", '"{}"'.format(OTHER_EMAIL))[1][0]
        if search:
            for msgid in search.split():
                msg = self.imap.fetch(msgid, "(RFC822)")[1][0][1]
                data = email.message_from_string(msg).get_payload(1).get_payload(decode=True)
                buf.append(data)
                self.imap.store(msgid, "+FLAGS", "\\Deleted")
        if buf:
            self.outgoing.sendall(b''.join(buf))

def _parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", dest="port", type=int, default=LOCAL_PORT,
                        help="port to run over")
    parser.add_argument("-s", dest="server", action="store_true",
                        help="run as server")
    return parser.parse_args()

def main():
    args = _parse_args()
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    if args.server:
        s.bind(('127.0.0.1', args.port))
        s.listen(4)
        print("Waiting for input")
        conn = s.accept()[0]
        print("Accepted connection")
    else:
        print("Connecting to server")
        s.connect(('127.0.0.1', args.port))
        conn = s

    mailer = Mailer()
    mailer.start()
    print("SMTP initialized")
    checker = MailChecker(conn)
    checker.start()
    print("IMAP initialized")
    try:
        while True:
            read, write, _ = select.select([conn], [], [])
            if read:
                mailer.queue.put(read[0].recv(65536))
    except:
        print("Shutting down")
        mailer.quit = True
        checker.stop()
        mailer.join()
        checker.join()
        conn.shutdown(socket.SHUT_RDWR)
        conn.close()
        if issubclass(sys.exc_info()[0], KeyboardInterrupt):
            return 0
        raise
    return 0

if __name__ == "__main__":
    sys.exit(main())
