﻿using Microsoft.AspNet.Identity;
using OrganWeb.Areas.Ecommerce.Models.zBanco;
using PagedList;
using PagedList.EntityFramework;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Threading.Tasks;
using System.Web;

namespace OrganWeb.Areas.Ecommerce.Models.ViewsBanco
{
    [Table("vwVenda")]
    public class VwVenda : EcommerceRepository<VwVenda>
    {
        public int Id { get; set; }
        public string IdCliente { get; set; }
        public string Data { get; set; }
        public string NomeAnuncio { get; set; }
        public double ValorTotal { get; set; }
        public string Endereco { get; set; }
        public string IdAnunciante { get; set; }
        public string Anunciante { get; set; }
        public string Situacao { get; set; }

        public async Task<IPagedList<VwVenda>> GetVendasAnunciante(int page)
        {
            string id = HttpContext.Current.User.Identity.GetUserId();
            return await DbSet.Where(x => x.IdAnunciante == id).OrderBy(p => p.Id).ToPagedListAsync(page, 10);
        }
    }
}