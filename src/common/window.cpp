#include "window.h"
#include <GLFW/glfw3.h>

namespace fart {

Window::Window(uint32_t w, uint32_t h, std::string title) : m_width(w), m_height(h), m_window_title(title) {
    initWindow();
}

Window::~Window() {
    glfwDestroyWindow(m_window);
    glfwTerminate();
}

void
Window::initWindow() {
    glfwInit();

#if OPENGL_RENDERER
    glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_API);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 5);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
#else 
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
#endif
    glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

    m_window = glfwCreateWindow(m_width, m_height, m_window_title.c_str(), nullptr, nullptr);

    glfwSetWindowUserPointer(m_window, this);
    glfwSetCursorPosCallback(m_window, [](GLFWwindow* window, double xpos, double ypos) {
        static_cast<Window*>(glfwGetWindowUserPointer(window))->cursorPositionCallback(window, xpos, ypos);
    });
    glfwSetMouseButtonCallback(m_window, [](GLFWwindow* window, int button, int action, int mods) {
        static_cast<Window*>(glfwGetWindowUserPointer(window))->mouseButtonCallback(window, button, action, mods);
    });

}

}
