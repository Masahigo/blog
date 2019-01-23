import webapp2

class MainPage(webapp2.RequestHandler):
    def get(self):
        # do this to redirect the default service and version only
        if self.request.host == 'ms-devops-dude.appspot.com':
            url = self.request.url.replace(self.request.host, 'msdevopsdude.com')
            return self.redirect(url, True)
        else:
            self.response.headers['Content-Type'] = 'text/plain'
            self.response.write("I am a redirect service at {0}".format(self.request.path))

app = webapp2.WSGIApplication([
    ('/.*', MainPage),
], debug=True)
