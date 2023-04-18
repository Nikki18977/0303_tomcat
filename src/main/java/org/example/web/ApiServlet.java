package org.example.web;

import java.io.*;
import jakarta.servlet.http.*;
import jakarta.servlet.annotation.*;

@WebServlet("/api")
public class ApiServlet extends HttpServlet {
  public void service(HttpServletRequest request, HttpServletResponse response) throws IOException {
    response.setContentType("application/json");

    final PrintWriter out = response.getWriter();
    out.println(
        // language=json
        """
        {"status": "ok"}
        """
    );
  }
}