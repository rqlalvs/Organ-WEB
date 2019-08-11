﻿using OrganWeb.Models;
using OrganWeb.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;
using System.Web;
using System.Web.Mvc;
using System.Web.Security;

namespace OrganWeb.Controllers
{
    public class UsuarioController : Controller
    {
        [HttpGet]
        public ActionResult Registro()
        {
            return View();
        }

        private Usuario usuario;

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public ActionResult Registro(RegistroViewModel model)
        {
            if (ModelState.IsValid)
            {
                 usuario = new Usuario { FirstName = model.FirstName, LastName = model.LastName, EmailID = model.EmailID, DateOfBirth = model.DateOfBirth, Password = model.Password };

                #region //verificar se o email existe
                if (VerificarEmail(usuario.EmailID))
                {
                    ModelState.AddModelError("EmailExistente", "Email já foi cadastrado.");
                    return View(model);
                }
                #endregion

                #region gera código de ativação
                usuario.ActivationCode = Guid.NewGuid();
                #endregion

                #region hashing
                usuario.Password = Criptografia.Hash(usuario.Password);
                //usuario.ConfirmPassword = Criptografia.Hash(usuario.ConfirmPassword);
                #endregion
                usuario.IsEmailVerified = false;

                #region salva no banco
                using (BancoContext db = new BancoContext())
                {
                    db.Usuarios.Add(usuario);
                    db.SaveChanges();

                    //envia detalhes por email
                    //EnviarEmailVerificacao(usuario.EmailID, usuario.ActivationCode.ToString());
                    return RedirectToAction("Index", "Home");
                }
                #endregion
            }
            return View(model);
        }
        
        [HttpGet]
        public ActionResult VerificarConta(string id)
        {
            bool Status = false;

            using (BancoContext db = new BancoContext())
            {
                db.Configuration.ValidateOnSaveEnabled = false;

                var v = db.Usuarios.Where(a => a.ActivationCode == new Guid(id)).FirstOrDefault();
                if (v != null)
                {
                    v.IsEmailVerified = true;
                    db.SaveChanges();
                    Status = true;
                }
                else
                {
                    ViewBag.Message = "Pedido inválido";
                }
            }
            ViewBag.Status = Status;
            return View();
        }

        [HttpGet]
        public ActionResult Login()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Login(LoginViewModel login, string ReturnUrl)
        {
            string mensagem;
            using (BancoContext db = new BancoContext())
            {
                var v = db.Usuarios.Where(a => a.EmailID == login.EmailID).FirstOrDefault();
                if (v != null)
                {
                    if (string.Compare(Criptografia.Hash(login.Password), v.Password) == 0)
                    {
                        int timeout = login.RememberMe ? 525600 : 20;
                        var ticket = new FormsAuthenticationTicket(login.EmailID, login.RememberMe, timeout);
                        string encrypted = FormsAuthentication.Encrypt(ticket);
                        var cookie = new HttpCookie(FormsAuthentication.FormsCookieName, encrypted)
                        {
                            Expires = DateTime.Now.AddMinutes(timeout),
                            HttpOnly = true
                        };
                        Response.Cookies.Add(cookie);

                        if (Url.IsLocalUrl(ReturnUrl))
                        {
                            return Redirect(ReturnUrl);
                        }
                        else
                        {
                            return RedirectToAction("Index", "Home");
                        }
                    }
                    else
                    {
                        mensagem = "Credenciais inválidas";
                    }
                }
                else
                {
                    mensagem = "Credenciais inválidas";
                }
            }
            ViewBag.Message = mensagem;
            return View();
        }

        [HttpPost]
        [Authorize]
        public ActionResult Logout()
        {
            FormsAuthentication.SignOut();
            return RedirectToAction("Login", "Usuario");
        }

        [NonAction]
        public bool VerificarEmail(string emailID)
        {
            using (BancoContext db = new BancoContext())
            {
                var v = db.Usuarios.Where(a => a.EmailID == emailID).FirstOrDefault();
                return v != null;
            }
        }

        [NonAction]
        public void EnviarEmailVerificacao(string emailID, string activationCode)
        {
            var verifyUrl = "/Usuario/VerificarConta/" + activationCode;
            var link = Request.Url.AbsoluteUri.Replace(Request.Url.PathAndQuery, verifyUrl);

            var fromEmail = new MailAddress("sameeranihathe@gmail.com", "sameera sampath");
            var toEmail = new MailAddress(emailID);
            var fromemailPassword = "kanchana143";

            string body = "<br/> <br/> Sua conta foi criada com sucesso. Por favor, clique no link abaixo para verificar sua conta." +
                "<br/> <br/> <a href='" + link + "'>" + link + "</a>";

            var smtp = new SmtpClient
            {
                Host = "smtp.gmail.com",
                Port = 587,
                EnableSsl = true,
                DeliveryMethod = SmtpDeliveryMethod.Network,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(fromEmail.Address, fromemailPassword)
            };

            using (var mensagem = new MailMessage(fromEmail, toEmail)
            {
                Subject = "Sua conta foi criada com sucesso.",
                Body = body,
                IsBodyHtml = true
            })
            {
                smtp.Send(mensagem);
            }
        }
    }
}